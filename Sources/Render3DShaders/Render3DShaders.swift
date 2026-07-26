import Foundation
import Metal
@_exported import Render3DShadersC

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

