import Metal

public protocol UniformProvider {
	static func allocateBuffer(for device: MTLDevice) -> MTLBuffer?
	func write(into buffer: MTLBuffer, offset: Int) -> Int
}

extension UniformProvider {
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

extension CameraUniforms: UniformProvider {}
extension SceneUniforms: UniformProvider {}
extension InstanceUniforms: UniformProvider {}

extension MTLBuffer {
	@discardableResult
	public func write<S: Collection, U>(
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
