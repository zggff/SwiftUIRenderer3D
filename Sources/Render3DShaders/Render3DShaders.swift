import Foundation
import Metal
import Render3DShadersC
@_exported import simd


public enum Uniforms {
	public typealias Instance = InstanceUniform
	public typealias Camera = CameraUniform
	public typealias SceneLight = SceneUniform
}

public typealias Vertex = Render3DShadersC.Vertex

extension Bundle {
	public static var render3DShaders: Bundle { .module }
}

extension Vertex {
	public static var defaultLayout: MTLVertexDescriptor {
		let vertexDescriptor = MTLVertexDescriptor()
		vertexDescriptor.attributes[0].format = .float3
		vertexDescriptor.attributes[0].bufferIndex = 0
		vertexDescriptor.attributes[0].offset = 0

		vertexDescriptor.attributes[1].format = .float3
		vertexDescriptor.attributes[1].bufferIndex = 0
		vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride

		vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
		return vertexDescriptor
	}
	public init(position: SIMD3<Float>) {
		self.init(position: position, normal: [0, 0, 0])
	}
}
