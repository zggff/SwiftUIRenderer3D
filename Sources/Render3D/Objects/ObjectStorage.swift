import Metal

public struct DrawInstruction {
	public init(mesh: Mesh? = nil, offset: Int, count: Int) {
		self.mesh = mesh
		self.offset = offset
		self.count = count
	}

	public let mesh: Mesh?
	public let offset: Int
	public let count: Int
}

public struct UniformRetrieavalError: Error, LocalizedError {
	let expected: Any.Type
	let from: Any.Type
	public var errorDescription: String? {
		return "Failed to create uniform '\(expected)' from '\(from)'."
	}
}

public protocol ObjectStorage: AnyObject {
	init()
	var count: Int { get }
	func append<T: Renderable>(_ objects: [T])
	func removeAll()
	func renderInfo<T: Uniform>(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?, as targetType: T.Type
	) throws -> [DrawInstruction]?
}

extension ObjectStorage {
	public func allocBuffer(device: MTLDevice, buffer: inout MTLBuffer?, stride: Int) {
		let size = count * stride
		guard size > 0 else { return }
		if let buffer = buffer, buffer.length >= size { return }
		buffer = device.makeBuffer(length: size)
	}
    @discardableResult
	public func writeToBuffer<T: Uniform>(
		buffer: MTLBuffer, objects: [any Renderable], offset: Int, of: T.Type
	) throws -> Int {
		return try buffer.write(
			objects, offset: offset,
			transform: { item in
				guard let uniform = item.uniform(of: of) else {
					throw UniformRetrieavalError(
						expected: T.self,
						from: type(of: item)
					)
				}
				return uniform
			})

	}
}

public class GroupedObjectStorage: ObjectStorage {
	typealias Element = any Renderable
	var storage: [ObjectIdentifier: [Element]] = [:]
	var instructions: [DrawInstruction] = []

	public var count: Int {
		storage.values.map(\.count).reduce(0, +)
	}

	public required init() {}

	public func append<T: Renderable>(_ objects: [T]) {
		guard !objects.isEmpty else { return }

		let id = ObjectIdentifier(T.self)
		if storage[id] == nil {
			storage[id] = []
		}
		storage[id]?.append(contentsOf: objects)
		instructions.removeAll(keepingCapacity: true)
	}

	public func removeAll() {
		storage = [:]
		instructions.removeAll(keepingCapacity: true)
	}

	public func renderInfo<T: Uniform>(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?, as targetType: T.Type
	) throws -> [DrawInstruction]? {
		guard count > 0 else {
			return nil
		}
		guard instructions.isEmpty else {
			return instructions
		}

		allocBuffer(device: device, buffer: &buffer, stride: MemoryLayout<T>.stride)
		guard let buffer else { return nil }

		var offset = 0
		for objects in storage.values {
			guard let first = objects.first else { continue }
			let mesh = cache.mesh(for: first)
			instructions.append(DrawInstruction(mesh: mesh, offset: offset, count: objects.count))
			offset += try writeToBuffer(
				buffer: buffer, objects: objects, offset: offset, of: targetType)
			//         try buffer.write(
			// objects, offset: offset,
			// transform: { item in
			// 	guard let uniform = item.uniform(of: targetType) else {
			// 		throw UniformRetrieavalError(
			// 			expected: T.self,
			// 			from: type(of: item)
			// 		)
			// 	}
			// 	return uniform
			// })
		}
		return instructions
	}
}
