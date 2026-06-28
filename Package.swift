// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "smart-mouse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SmartMouse", targets: ["SmartMouse"])
    ],
    targets: [
        .executableTarget(
            name: "SmartMouse",
            path: "Sources/SmartMouse",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Packaging/Info.plist"
                ])
            ]
        )
    ]
)
