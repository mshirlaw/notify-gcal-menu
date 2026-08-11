// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotifyGCalMenu",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "NotifyGCalMenu",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/NotifyGCalMenu",
            exclude: ["Resources/Secrets.plist.example"],
            resources: [.copy("Resources/Secrets.plist")]
        )
    ]
)
