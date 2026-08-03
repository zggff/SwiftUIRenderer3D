import Metal

public struct DrawInstruction {
	public init(mesh: GPUMesh, offset: Int, count: Int) {
		self.mesh = mesh
		self.offset = offset
		self.count = count
	}

	public let mesh: GPUMesh
	public let offset: Int
	public let count: Int
}

public typealias UniformMeshProvider<T> = UniformProvider<T> & MeshProvider

public protocol ObjectStorage<UniformType>: AnyObject {
	associatedtype UniformType
	associatedtype Element = any UniformMeshProvider<UniformType>

	init()
	var count: Int { get }
	func append<T: UniformMeshProvider<UniformType>>(objects: [T]) throws

	func removeAll()
	func renderInfo(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?
	) throws -> [DrawInstruction]
}

extension ObjectStorage {
	@discardableResult
	public func allocBuffer<U: Uniform>(
		device: MTLDevice, buffer: inout MTLBuffer?, for targetType: U.Type
	) throws -> MTLBuffer {
		let size = count * MemoryLayout<U>.stride
		if let buffer = buffer, buffer.length >= size { return buffer }
		guard let newBuffer = device.makeBuffer(length: size) else {
			throw RenderError.allocation(size: size, type: targetType)
		}
		buffer = newBuffer
		return newBuffer
	}
	@discardableResult
	public func allocBuffer<U: Uniform>(
		device: MTLDevice, buffer: inout MTLBuffer?, data: Data, targetType: U.Type
	) throws -> MTLBuffer {
		if let buffer = buffer, buffer.length >= data.count { return buffer }
		guard let newBuffer = device.makeBuffer(length: data.count) else {
			throw RenderError.allocation(size: data.count, type: targetType)
		}
		buffer = newBuffer
		return newBuffer
	}

	public func writeDataToBuffer<U: Uniform>(
		device: MTLDevice, buffer: inout MTLBuffer?, data: Data, targetType: U.Type
	) throws {
		guard data.count > 0 else { return }
		let buffer = try allocBuffer(
			device: device, buffer: &buffer, data: data, targetType: targetType)
		data.withUnsafeBytes({ ptr in
			guard let baseAddress = ptr.baseAddress else { return }
			buffer.contents().copyMemory(from: baseAddress, byteCount: data.count)
		})
	}
}
