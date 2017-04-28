import PackageDescription

let package = Package(
    name: "Sparrow",
    targets: [
        Target(name: "Core"),
        Target(name: "POSIX"),
        Target(name: "Networking", dependencies: ["Core", "POSIX"]),
        Target(name: "HTTP", dependencies: ["Networking"]),
        Target(name: "Crest", dependencies: ["HTTP"]),
        Target(name: "Sparrow", dependencies: ["Crest", "HTTP"]),
    ],
    dependencies: [
        .Package(url: "https://github.com/formbound/Venice.git", majorVersion: 0),
        .Package(url: "https://github.com/Zewo/CDNS.git", majorVersion: 0),
        .Package(url: "https://github.com/Zewo/CPOSIX.git", majorVersion: 0),
        .Package(url: "https://github.com/Zewo/CHTTPParser.git", majorVersion: 0),
        .Package(url: "https://github.com/formbound/Powerline.git", majorVersion: 0),
        .Package(url: "https://github.com/Zewo/CYAJL.git", majorVersion: 0)
    ]
)
