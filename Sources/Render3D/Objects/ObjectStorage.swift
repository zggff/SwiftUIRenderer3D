import Metal

public struct DrawInstruction {
	public init(mesh: Mesh, offset: Int, count: Int) {
		self.mesh = mesh
		self.offset = offset
		self.count = count
	}

	public let mesh: Mesh
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
	public func allocBuffer<U: Uniform>(
		device: MTLDevice, buffer: inout MTLBuffer?, for targetType: U.Type
	) throws {
		let size = count * MemoryLayout<U>.stride
		if let buffer = buffer, buffer.length >= size { return }
		guard let newBuffer = device.makeBuffer(length: size) else {
            throw RenderError.allocation(size: size, type: targetType)
		}
		buffer = newBuffer
	}
}

public class GroupedObjectStorage: ObjectStorage {
	typealias Element = any Renderable
	var storage: [MeshID: [Element]] = [:]
	var instructions: [DrawInstruction] = []

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
	}

	public func removeAll() {
		storage = [:]
		instructions.removeAll(keepingCapacity: true)
	}

	public func renderInfo<U: Uniform>(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?, as targetType: U.Type,
		transform: (any Renderable) throws -> U
	) throws -> [DrawInstruction] {
		guard count > 0 else {
			return []
		}
		guard instructions.isEmpty else {
			return instructions
		}

		try allocBuffer(device: device, buffer: &buffer, for: targetType)
		guard let buffer else { return [] }

		var offset = 0
		for objects in storage.values {
			guard let first = objects.first,
				let mesh = try cache.mesh(for: first)
			else { continue }
			instructions.append(DrawInstruction(mesh: mesh, offset: offset, count: objects.count))
			offset += try buffer.write(objects, offset: offset, transform: transform)
		}
		return instructions
	}
}
