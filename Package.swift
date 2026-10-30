// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Visor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Visor", targets: ["Visor"])
    ],
    targets: [
        .target(
            name: "PTYShim",
            path: "Sources/PTYShim",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "Visor",
            dependencies: ["PTYShim"],
            path: "Sources/Visor",
            resources: [.copy("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "VisorTests",
            dependencies: ["Visor"],
            path: "Tests/VisorTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
