// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CameraImageWorker",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "CameraImageWorker", targets: ["CameraImageWorker"])
    ],
    targets: [
        .executableTarget(name: "CameraImageWorker"),
        .testTarget(name: "CameraImageWorkerTests", dependencies: ["CameraImageWorker"])
    ]
)
