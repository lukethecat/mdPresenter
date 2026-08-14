// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Presenter",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "PresenterCore", targets: ["PresenterCore"]),
        .executable(name: "Presenter", targets: ["Presenter"]),
    ],
    targets: [
        .target(
            name: "PresenterCore",
            path: "Sources/PresenterCore"
        ),
        .executableTarget(
            name: "Presenter",
            dependencies: ["PresenterCore"],
            path: "Sources/Presenter"
        ),
        .testTarget(
            name: "PresenterCoreTests",
            dependencies: ["PresenterCore", "Presenter"],
            path: "Tests/PresenterCoreTests"
        ),
    ]
)
