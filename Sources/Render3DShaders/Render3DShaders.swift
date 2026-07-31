import Foundation
@_exported import Metal
import Render3DShadersC
@_exported import simd

public enum Uniforms {
	public typealias Instance = InstanceUniform
	public typealias Camera = CameraUniform
	public typealias SceneLight = SceneUniform
	public enum VertexColorType: Int32 {
        case ignore = 0
        case useAsColor = 1
        case useAsUV = 2
	}
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

		vertexDescriptor.attributes[2].format = .float3
		vertexDescriptor.attributes[2].bufferIndex = 0
		vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2

		vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
		return vertexDescriptor
	}
	public init(
		position: SIMD3<Float>, normal: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
		color: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
	) {
		self.init()
		self.position = position
		self.normal = normal
		self.colorUV = color
	}
}
