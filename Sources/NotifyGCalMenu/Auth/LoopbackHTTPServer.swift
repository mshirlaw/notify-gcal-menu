import Darwin
import Foundation

/**
 * A one-shot local HTTP listener used to capture Google's OAuth redirect, per the loopback
 * interception pattern for installed apps (RFC 8252). Handles exactly one request, then stops.
 *
 * This is built on raw POSIX sockets rather than Network.framework: on machines running
 * endpoint security software with a network-monitoring system extension (observed here with
 * SentinelOne), `NWListener` reliably fails with `EINVAL` even for a plain loopback listener,
 * while direct `socket`/`bind`/`listen` calls are unaffected.
 */
final class LoopbackHTTPServer: @unchecked Sendable {
    enum LoopbackError: Error, LocalizedError {
        case socketError(String)
        case invalidRequest
        case oauthError(String)
        case stateMismatch
        case timedOut

        var errorDescription: String? {
            switch self {
            case .socketError(let message): return "Local sign-in listener failed: \(message)"
            case .invalidRequest: return "The sign-in redirect request was malformed."
            case .oauthError(let message): return "Google reported an error: \(message)"
            case .stateMismatch: return "The sign-in redirect's state didn't match — possible tampering, aborting."
            case .timedOut: return "Sign-in timed out waiting for you to finish in the browser."
            }
        }
    }

    private var listenSocket: Int32 = -1

    /**
     * Starts a TCP listener bound only to 127.0.0.1, on an ephemeral port.
     */
    func start() throws -> UInt16 {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { throw LoopbackError.socketError("socket(): \(lastErrorMessage())") }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else {
            let message = lastErrorMessage()
            Darwin.close(sock)
            throw LoopbackError.socketError("bind(): \(message)")
        }

        guard listen(sock, 1) == 0 else {
            let message = lastErrorMessage()
            Darwin.close(sock)
            throw LoopbackError.socketError("listen(): \(message)")
        }

        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let namedResult = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(sock, $0, &len) }
        }
        guard namedResult == 0 else {
            let message = lastErrorMessage()
            Darwin.close(sock)
            throw LoopbackError.socketError("getsockname(): \(message)")
        }

        listenSocket = sock
        let port = UInt16(bigEndian: boundAddr.sin_port)
        Log.auth.debug("Loopback listener bound to 127.0.0.1:\(port, privacy: .public)")
        return port
    }

    /**
     * Blocks (on a background thread) until a client connects, then parses its request,
     * validates `state`, and returns the authorization code.
     */
    func waitForRedirect(expectedState: String) async throws -> String {
        let socket = listenSocket
        guard socket >= 0 else { throw LoopbackError.invalidRequest }

        return try await withCheckedThrowingContinuation { continuation in
            Thread.detachNewThread { [weak self] in
                guard let self else {
                    continuation.resume(throwing: LoopbackError.invalidRequest)
                    return
                }
                do {
                    let code = try self.acceptAndHandleOneRequest(listenSocket: socket, expectedState: expectedState)
                    continuation.resume(returning: code)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        if listenSocket >= 0 {
            Darwin.close(listenSocket)
            listenSocket = -1
        }
    }

    private func acceptAndHandleOneRequest(listenSocket: Int32, expectedState: String) throws -> String {
        let clientSocket = accept(listenSocket, nil, nil)
        guard clientSocket >= 0 else {
            throw LoopbackError.socketError("accept(): \(lastErrorMessage())")
        }
        defer { Darwin.close(clientSocket) }

        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = buffer.withUnsafeMutableBytes { read(clientSocket, $0.baseAddress, $0.count) }
        guard bytesRead > 0 else {
            throw LoopbackError.invalidRequest
        }

        let requestText = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
        guard
            let requestLine = requestText.split(separator: "\r\n").first,
            let path = requestLine.split(separator: " ").dropFirst().first,
            let components = URLComponents(string: "http://127.0.0.1\(path)")
        else {
            Log.auth.error("Loopback request didn't parse, received \(bytesRead, privacy: .public) bytes")
            send(clientSocket, success: false)
            throw LoopbackError.invalidRequest
        }
        Log.auth.debug("Loopback request line: \(String(requestLine), privacy: .public)")

        let queryItems = components.queryItems ?? []
        if let oauthError = queryItems.first(where: { $0.name == "error" })?.value {
            send(clientSocket, success: false)
            throw LoopbackError.oauthError(oauthError)
        }
        guard let state = queryItems.first(where: { $0.name == "state" })?.value, state == expectedState else {
            send(clientSocket, success: false)
            throw LoopbackError.stateMismatch
        }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            send(clientSocket, success: false)
            throw LoopbackError.invalidRequest
        }

        send(clientSocket, success: true)
        return code
    }

    private func send(_ clientSocket: Int32, success: Bool) {
        let title = success ? "Signed in" : "Sign-in failed"
        let body = success
            ? "You can close this window and return to Notify GCal."
            : "Something went wrong. You can close this window and try again."
        let html = """
        <html><body style="font-family: -apple-system, sans-serif; padding: 2rem;">
        <h2>\(title)</h2><p>\(body)</p></body></html>
        """
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
        let bytes = Array(response.utf8)
        bytes.withUnsafeBufferPointer { _ = write(clientSocket, $0.baseAddress, $0.count) }
    }

    private func lastErrorMessage() -> String {
        String(cString: strerror(errno))
    }
}
