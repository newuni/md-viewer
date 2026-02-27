// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "md-viewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MarkdownRendererCore",
            targets: ["MarkdownRendererCore"]
        ),
        .executable(
            name: "md-viewer",
            targets: ["MDViewerCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.7.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.2.3")
    ],
    targets: [
        .target(
            name: "MarkdownRendererCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .executableTarget(
            name: "MDViewerCLI",
            dependencies: ["MarkdownRendererCore"]
        ),
        .testTarget(
            name: "MarkdownRendererCoreTests",
            dependencies: [
                "MarkdownRendererCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
