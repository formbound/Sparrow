import PackageDescription

let package = Package(
    name: "Sparrow",
    targets: [
        Target(name: "CDNS"),
        Target(name: "CPOSIX"),
        Target(name: "CHTTPParser"),
        Target(name: "CYAJL"),
        
        Target(name: "POSIX", dependencies: ["CPOSIX"]),
        Target(name: "Core", dependencies: ["CYAJL"]),
        Target(name: "Networking", dependencies: ["CDNS", "Core", "POSIX"]),
        Target(name: "HTTP", dependencies: ["CHTTPParser", "Networking"]),
        Target(name: "Crest", dependencies: ["HTTP"]),
        Target(name: "Sparrow", dependencies: ["HTTP"]),
        Target(name: "Example", dependencies: ["Sparrow"]),
    ],
    dependencies: [
        .Package(url: "https://github.com/formbound/Venice.git", majorVersion: 0),
        .Package(url: "https://github.com/formbound/Powerline.git", majorVersion: 0),
    ]
)
