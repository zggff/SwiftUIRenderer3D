public class GroupedObjectStorage<UniformType: Uniform>: ObjectStorage {
	var storage: [MeshID: [Element]] = [:]
	var instructions: [DrawInstruction] = []
	var uniformsData: Data? = nil

	public var count: Int {
		storage.values.map(\.count).reduce(0, +)
	}

	public required init() {}

	public func append(typeErased objects: [any UniformProvider & MeshProvider]) throws {
		guard let objects = objects as? [Element] else {
			throw RenderError.scene(.invalidStorage)
		}
		append(objects: objects)
	}

	public func append(objects: [Element]) {
		guard !objects.isEmpty else { return }
		for obj in objects {
			storage[obj.meshId, default: []].append(obj)
		}
		instructions.removeAll(keepingCapacity: true)
		uniformsData = nil
	}

	public func removeAll() {
		storage = [:]
		instructions.removeAll(keepingCapacity: true)
		uniformsData = nil
	}

	public func renderInfo(
		device: MTLDevice, cache: MeshCache, buffer: inout MTLBuffer?
	)
		throws -> [DrawInstruction]
	{
		guard count > 0 else {
			return []
		}
		if let uniformsData, !instructions.isEmpty {
			try writeDataToBuffer(
				device: device, buffer: &buffer, data: uniformsData, targetType: UniformType.self)
			return instructions
		}

		var uniforms: [UniformType] = []
		uniforms.reserveCapacity(count)
		instructions.removeAll(keepingCapacity: true)

		var offset = 0
		for objects in storage.values {
			guard let first = objects.first,
				let mesh = try cache.mesh(for: first)
			else { continue }
			uniforms.append(
				contentsOf: objects.map { o in o.uniform() }
			)
			instructions.append(DrawInstruction(mesh: mesh, offset: offset, count: objects.count))
			offset += MemoryLayout<UniformType>.stride * objects.count
		}

		let data = uniforms.withUnsafeBytes { Data($0) }
		uniformsData = data
		try writeDataToBuffer(
			device: device, buffer: &buffer, data: data, targetType: UniformType.self)

		return instructions
	}
}
