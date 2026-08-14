import Foundation

/// Google OAuth "Desktop app" client credentials, loaded from the bundled Secrets.plist.
/// The client secret isn't confidential for installed-app OAuth clients (it ships in the
/// binary), but it's still kept out of git via Secrets.plist.example + .gitignore.
struct Secrets {
    let googleClientID: String
    let googleClientSecret: String

    static let shared: Secrets = {
        guard
            let url = Bundle.module.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
            let clientID = plist["GoogleClientID"],
            let clientSecret = plist["GoogleClientSecret"]
        else {
            fatalError("Missing or malformed Secrets.plist. Copy Resources/Secrets.plist.example to Resources/Secrets.plist and fill in your OAuth client credentials.")
        }
        return Secrets(googleClientID: clientID, googleClientSecret: clientSecret)
    }()

    var isConfigured: Bool {
        !googleClientID.contains("YOUR_CLIENT_ID") && !googleClientSecret.contains("YOUR_CLIENT_SECRET")
    }
}
