import Foundation
import Metal
@_exported import Render3DShadersC

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

public protocol WritableIntoBuffer {}

extension CameraUniforms: WritableIntoBuffer {}
extension SceneUniforms: WritableIntoBuffer {}

extension WritableIntoBuffer {
	public func write(into buffer: MTLBuffer, offset: Int = 0) {
		withUnsafeBytes(of: self) { bytes in
			buffer.contents()
				.advanced(by: offset)
				.copyMemory(
					from: bytes.baseAddress!, byteCount: MemoryLayout<Self>.stride)
		}
	}
	public static func allocateBuffer(for device: MTLDevice) -> MTLBuffer? {
		device.makeBuffer(length: MemoryLayout<Self>.stride)
	}
}

extension Bundle {
	public static var render3DShaders: Bundle { .module }
}
