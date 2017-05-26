import PackageDescription

let package = Package(
    name: "Sparrow",
    targets: [
        Target(name: "Sparrow"),
        Target(name: "Example", dependencies: ["Sparrow"]),
    ],
    dependencies: [
        .Package(url: "https://github.com/Zewo/Zewo.git", majorVersion: 0, minor: 13),
    ]
)
