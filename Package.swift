// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cadence",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Cadence", targets: ["Cadence"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .executableTarget(
            name: "Cadence",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Cadence",
            exclude: [
                "Resources/AppIcon.svg",
                "Resources/AppIcon.icns",
                "Resources/MenubarIcons"
            ],
            resources: []
        )
    ]
)
