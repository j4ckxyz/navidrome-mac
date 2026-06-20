// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NavidromeMac",
    platforms: [
        // macOS 14 is the minimum that compiles all APIs used here.
        // Liquid Glass refinements (.glassEffect) light up automatically on
        // macOS 26 "Tahoe" via #available checks inside the views.
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NavidromeMac", targets: ["NavidromeMac"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NavidromeMac",
            path: "Sources/NavidromeMac",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
