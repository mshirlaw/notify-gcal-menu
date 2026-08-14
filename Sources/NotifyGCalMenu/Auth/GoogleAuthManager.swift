import Foundation
import AppKit

enum AuthError: Error, LocalizedError {
    case notConfigured
    case invalidAuthURL
    case notSignedIn
    case noRefreshToken
    case tokenRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Secrets.plist still has placeholder OAuth credentials. See README.md's setup section."
        case .invalidAuthURL: return "Could not build the Google sign-in URL."
        case .notSignedIn: return "Not signed in."
        case .noRefreshToken: return "Google did not return a refresh token. Try signing out and in again."
        case .tokenRequestFailed(let message): return message
        }
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: TimeInterval
    let refreshToken: String?
}

/// Handles Google OAuth sign-in/out and access-token refresh for a "Desktop app" OAuth
/// client, using the loopback redirect flow with PKCE. The refresh token is the only
/// long-lived secret and is stored in the Keychain; the access token is kept in memory
/// and refreshed on demand.
actor GoogleAuthManager {
    static let shared = GoogleAuthManager()

    private let keychainAccount = "primary"
    private var accessToken: String?
    private var accessTokenExpiry: Date?

    var isSignedIn: Bool {
        KeychainStore.read(account: keychainAccount) != nil
    }

    func signIn() async throws {
        guard Secrets.shared.isConfigured else {
            Log.auth.error("signIn aborted: Secrets.plist not configured")
            throw AuthError.notConfigured
        }

        let server = LoopbackHTTPServer()
        let port = try server.start()
        defer { server.stop() }

        let verifier = PKCE.randomURLSafeString()
        let challenge = PKCE.codeChallenge(forVerifier: verifier)
        let state = PKCE.randomURLSafeString(byteCount: 16)
        let redirectURI = "http://127.0.0.1:\(port)/"

        guard let authURL = buildAuthorizationURL(redirectURI: redirectURI, challenge: challenge, state: state) else {
            Log.auth.error("signIn aborted: could not build authorization URL")
            throw AuthError.invalidAuthURL
        }

        Log.auth.debug("Opening authorization URL: \(authURL.absoluteString)")
        NSWorkspace.shared.open(authURL)

        let code: String
        do {
            code = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { try await server.waitForRedirect(expectedState: state) }
                group.addTask {
                    try await Task.sleep(for: .seconds(180))
                    throw LoopbackHTTPServer.LoopbackError.timedOut
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
        } catch {
            Log.auth.error("Did not receive a usable redirect: \(error.localizedDescription)")
            throw error
        }

        Log.auth.debug("Exchanging authorization code for tokens")
        let tokens = try await exchangeCodeForTokens(code: code, redirectURI: redirectURI, verifier: verifier)
        guard let refreshToken = tokens.refreshToken else {
            Log.auth.error("Token exchange succeeded but no refresh_token was returned")
            throw AuthError.noRefreshToken
        }

        KeychainStore.save(refreshToken, account: keychainAccount)
        accessToken = tokens.accessToken
        accessTokenExpiry = Date().addingTimeInterval(tokens.expiresIn)
        Log.auth.debug("Sign-in succeeded")
    }

    func signOut() async {
        if let token = try? await validAccessToken() {
            await revoke(token: token)
        }
        KeychainStore.delete(account: keychainAccount)
        accessToken = nil
        accessTokenExpiry = nil
    }

    /// Returns a non-expired access token, refreshing it first if needed.
    func validAccessToken() async throws -> String {
        if let accessToken, let expiry = accessTokenExpiry, expiry > Date().addingTimeInterval(60) {
            return accessToken
        }
        guard let refreshToken = KeychainStore.read(account: keychainAccount) else {
            throw AuthError.notSignedIn
        }
        let tokens = try await refreshAccessToken(refreshToken: refreshToken)
        accessToken = tokens.accessToken
        accessTokenExpiry = Date().addingTimeInterval(tokens.expiresIn)
        return tokens.accessToken
    }

    /// Discards the in-memory access token so the next request is forced to refresh it,
    /// e.g. after the Calendar API reports the token as expired or revoked.
    func invalidateAccessToken() {
        accessToken = nil
        accessTokenExpiry = nil
    }

    private func buildAuthorizationURL(redirectURI: String, challenge: String, state: String) -> URL? {
        var components = URLComponents(string: Constants.authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: Secrets.shared.googleClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Constants.calendarReadonlyScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components?.url
    }

    private func exchangeCodeForTokens(code: String, redirectURI: String, verifier: String) async throws -> TokenResponse {
        try await requestTokens(body: [
            "code": code,
            "client_id": Secrets.shared.googleClientID,
            "client_secret": Secrets.shared.googleClientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ])
    }

    private func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        try await requestTokens(body: [
            "refresh_token": refreshToken,
            "client_id": Secrets.shared.googleClientID,
            "client_secret": Secrets.shared.googleClientSecret,
            "grant_type": "refresh_token",
        ])
    }

    private func requestTokens(body: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: Constants.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.auth.error("Token endpoint returned \((response as? HTTPURLResponse)?.statusCode ?? -1): \(message)")
            throw AuthError.tokenRequestFailed(message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TokenResponse.self, from: data)
    }

    private func revoke(token: String) async {
        var request = URLRequest(url: URL(string: Constants.revokeEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(["token": token])
        _ = try? await URLSession.shared.data(for: request)
    }

    private func formEncode(_ params: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
        let pairs = params.map { key, value -> String in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}
