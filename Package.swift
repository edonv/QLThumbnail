// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QLThumbnail",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .macCatalyst(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "QLThumbnail",
            targets: ["QLThumbnail"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/shaps80/SwiftUIBackports.git", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "QLThumbnail",
            dependencies: [.byNameItem(name: "SwiftUIBackports", condition: nil)]),
        .testTarget(
            name: "QLThumbnailTests",
            dependencies: ["QLThumbnail"]),
    ]
)
