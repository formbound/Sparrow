// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Sparrow",
    products: [
        .library(
            name: "Sparrow",
            type: .dynamic,
            targets: [
               "Sparrow"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Zewo/Zewo.git", .branch("swift-4"))
    ],
    targets: [
        .target(name: "Sparrow", dependencies: ["Zewo"]),
        .testTarget(name: "SparrowTests", dependencies: ["Sparrow"]),
    ]
)
