// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Renderer3D",
	platforms: [
		.macOS(.v15),
		.iOS(.v16),
	],
	products: [
		.library(
			name: "Renderer3D",
			targets: ["Renderer3D"]
		)
	],
	targets: [
        .target(
            name: "SharedShaderTypes",
            publicHeadersPath: ".",
        ),
		.target(
			name: "Renderer3D",
            dependencies: ["SharedShaderTypes"],
			resources: [
				.process("Shader/shader.metal")
			],
		)
	],
	swiftLanguageModes: [.v6]
)
