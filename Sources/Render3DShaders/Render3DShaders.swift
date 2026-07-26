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

public protocol WritableIntoBuffer {
	func write(into buffer: MTLBuffer, offset: Int) -> Int
}

extension WritableIntoBuffer {
	@discardableResult
	public func write(into buffer: MTLBuffer, offset: Int = 0) -> Int {
		withUnsafeBytes(of: self) { bytes in
			buffer.contents()
				.advanced(by: offset)
				.copyMemory(
					from: bytes.baseAddress!, byteCount: MemoryLayout<Self>.stride)
		}
		return MemoryLayout<Self>.stride
	}

	public static func allocateBuffer(for device: MTLDevice) -> MTLBuffer? {
		device.makeBuffer(length: MemoryLayout<Self>.stride)
	}
}

extension CameraUniforms: WritableIntoBuffer {}
extension SceneUniforms: WritableIntoBuffer {}
extension InstanceUniforms: WritableIntoBuffer {}

extension [InstanceUniforms]: WritableIntoBuffer {
	@discardableResult
	public func write(into buffer: MTLBuffer, offset: Int = 0) -> Int {
		let byteCount = self.count * MemoryLayout<InstanceUniforms>.stride
		self.withUnsafeBufferPointer { bytes in
			buffer.contents()
				.advanced(by: offset)
				.copyMemory(
					from: bytes.baseAddress!,
					byteCount: byteCount)
		}
		return byteCount
	}
}

extension Bundle {
	public static var render3DShaders: Bundle { .module }
}

extension MTLBuffer {
	@discardableResult
	public func write<S: Sequence, U>(
		_ objects: S,
		offset: Int = 0,
		transform: (S.Element) -> U
	) -> Int {
		let stride = MemoryLayout<U>.stride
		let pointer = self.contents()
			.advanced(by: offset)
			.assumingMemoryBound(to: U.self)

		let bufferPointer = UnsafeMutableBufferPointer(
			start: pointer, count: objects.underestimatedCount)

		var count = 0
		for (index, object) in objects.enumerated() {
			bufferPointer[index] = transform(object)
			count += 1
		}

		return count * stride
	}
}
