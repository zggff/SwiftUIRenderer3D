import Metal
import Render3DShadersC

public protocol Uniform {
	func allocateBuffer(for device: any MTLDevice, buffer: inout MTLBuffer?)
	func write(into buffer: MTLBuffer?, offset: Int) -> Int
	var requiredSize: Int { get }
}

extension Uniform {
	@discardableResult
	public func write(into buffer: MTLBuffer?, offset: Int = 0) -> Int {
		guard let buffer else { return 0 }
		withUnsafeBytes(of: self) { bytes in
			buffer.contents()
				.advanced(by: offset)
				.copyMemory(
					from: bytes.baseAddress!, byteCount: MemoryLayout<Self>.stride)
		}
		return MemoryLayout<Self>.stride
	}

	public var requiredSize: Int { MemoryLayout<Self>.stride }

	public func allocateBuffer(for device: any MTLDevice, buffer: inout MTLBuffer?) {
		if (buffer?.length ?? 0) < requiredSize {
			buffer = device.makeBuffer(length: requiredSize)
		}
	}

	@discardableResult
	public func allocateAndWrite(
		for device: any MTLDevice, buffer: inout MTLBuffer?, offset: Int = 0
	) -> Int {
		allocateBuffer(for: device, buffer: &buffer)
		return write(into: buffer, offset: offset)

	}
}

extension CameraUniform: Uniform {}
extension SceneUniform: Uniform {}
extension InstanceUniform: Uniform {}

extension MTLBuffer {
	@discardableResult
	public func write<S: Collection, U>(
		_ objects: S,
		offset: Int = 0,
		transform: (S.Element) throws -> U
	) rethrows -> Int {
		let stride = MemoryLayout<U>.stride
		let pointer = self.contents()
			.advanced(by: offset)
			.assumingMemoryBound(to: U.self)

		let bufferPointer = UnsafeMutableBufferPointer(
			start: pointer, count: objects.underestimatedCount)

		var count = 0
		for (index, object) in objects.enumerated() {
			bufferPointer[index] = try transform(object)
			count += 1
		}
		return count * stride
	}

}
