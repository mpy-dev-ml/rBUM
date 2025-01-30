// swift-tools-version: 5.9.2
import PackageDescription

let package = Package(
    name: "rBUM",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "rBUM",
            targets: ["rBUM"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "rBUM",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImportObjcForwardDeclarations"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "rBUMTests",
            dependencies: ["rBUM"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImportObjcForwardDeclarations"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
