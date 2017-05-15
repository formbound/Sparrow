import PackageDescription

let package = Package(
    name: "Sparrow",
    targets: [
        Target(name: "Sparrow"),
    ],
    dependencies: [
        .Package(url: "https://github.com/Zewo/Zewo.git", majorVersion: 0, minor: 8),
    ]
)
