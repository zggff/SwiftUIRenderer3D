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

public protocol ObjectStorage: AnyObject {
	init()
	var count: Int { get }
	func append(_ objects: [any Renderable])

	func removeAll()
	func renderInfo<U: Uniform>(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?, as targetType: U.Type,
		transform: (any Renderable) throws -> U
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

public class GroupedObjectStorage: ObjectStorage {
	typealias Element = any Renderable
	var storage: [MeshID: [Element]] = [:]
	var instructions: [DrawInstruction] = []
	var uniformsByType: [ObjectIdentifier: Data] = [:]

	public var count: Int {
		storage.values.map(\.count).reduce(0, +)
	}

	public required init() {}

	public func append(_ objects: [any Renderable]) {
		guard !objects.isEmpty else { return }
		for obj in objects {
			storage[obj.meshId, default: []].append(obj)
		}
		instructions.removeAll(keepingCapacity: true)
		uniformsByType.removeAll(keepingCapacity: true)
	}

	public func removeAll() {
		storage = [:]
		instructions.removeAll(keepingCapacity: true)
		uniformsByType.removeAll(keepingCapacity: true)
	}

	public func renderInfo<U: Uniform>(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?, as targetType: U.Type,
		transform: (any Renderable) throws -> U
	) throws -> [DrawInstruction] {
		guard count > 0 else {
			return []
		}
		let key = ObjectIdentifier(targetType)

		if let uniformData = uniformsByType[key], !instructions.isEmpty {
			try writeDataToBuffer(
				device: device, buffer: &buffer, data: uniformData, targetType: targetType)
			return instructions
		}

		var uniforms: [U] = []
		uniforms.reserveCapacity(count)
		instructions.removeAll(keepingCapacity: true)

		var offset = 0
		for objects in storage.values {
			guard let first = objects.first,
				let mesh = try cache.mesh(for: first)
			else { continue }
			uniforms.append(contentsOf: try objects.map(transform))
			instructions.append(DrawInstruction(mesh: mesh, offset: offset, count: objects.count))
			offset += MemoryLayout<U>.stride * objects.count
		}

		let data = uniforms.withUnsafeBytes { Data($0) }
		uniformsByType[key] = data
		try writeDataToBuffer(device: device, buffer: &buffer, data: data, targetType: targetType)

		return instructions
	}
}
