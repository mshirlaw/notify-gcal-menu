// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotifyGCalMenu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotifyGCalMenu",
            path: "Sources/NotifyGCalMenu",
            exclude: ["Resources/Secrets.plist.example"],
            resources: [.copy("Resources/Secrets.plist")]
        )
    ]
)
