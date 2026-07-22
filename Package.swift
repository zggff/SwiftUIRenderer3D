// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Render3D",
	platforms: [
		.macOS(.v15),
		.iOS(.v18),
	],
	products: [
		.library(
			name: "Render3D",
			targets: ["Render3D"]
		),
		.library(
			name: "Render3DViews",
			targets: ["Render3DViews"]
		),

	],
	targets: [
		.target(
			name: "Render3DShadersC",
			publicHeadersPath: ".",
		),

		.target(
			name: "Render3DShaders",
			dependencies: ["Render3DShadersC"],
			resources: [
				.process("Shaders")
			],
		),
		.target(
			name: "Render3D",
			dependencies: ["Render3DShaders"],
		),
		.target(
			name: "Render3DViews",
			dependencies: ["Render3D"],
		),
	],
	swiftLanguageModes: [.v6]
)
