// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "es-kit",
    platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ESKit",
            targets: ["ESKit"]),
        .library(name: "ESKitFluentSQLDatabaseDriver", targets: ["ESKitFluentSQLDatabaseDriver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ESKit"),
        .testTarget(
            name: "ESKitTests",
            dependencies: ["ESKit"]
        ),
        
        .target(name: "ESKitFluentSQLDatabaseDriver", dependencies: [
            .target(name: "ESKit"),
            .product(name: "Fluent", package: "fluent"),
        ]),
        .testTarget(
            name: "ESKitFluentSQLDatabaseDriverTests",
            dependencies: [
                "ESKitFluentSQLDatabaseDriver",
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]
        ),
    ]
)
