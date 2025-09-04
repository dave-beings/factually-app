// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Factually",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "Factually",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ]
        )
    ]
)
