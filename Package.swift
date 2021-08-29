// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServerSolidAccount",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ServerSolidAccount",
            targets: ["ServerSolidAccount"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SyncServerII/ServerAccount.git", from: "0.0.2"),
        .package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", from: "2.5.0"),
        .package(url: "https://github.com/crspybits/SolidAuthSwift.git", from: "0.0.2"),
        .package(url: "https://github.com/SyncServerII/ServerShared.git", from: "0.9.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ServerSolidAccount",
            dependencies: [
                "ServerAccount",
                "ServerShared",
                .product(name: "Credentials", package: "Kitura-Credentials"),
                .product(name: "SolidAuthSwiftTools", package: "SolidAuthSwift"),
            ]),
        .testTarget(
            name: "ServerSolidAccountTests",
            dependencies: ["ServerSolidAccount"],
            resources: [
                .copy("Cat.jpg"),
                .copy("Sake.png"),
                .copy("Squidly.mov"),
                .copy("Website.url"),
                .copy("Example.gif")
            ]),
    ]
)
