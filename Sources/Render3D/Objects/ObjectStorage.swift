import Metal

public class ObjectStorage {
	var cachable: [ObjectIdentifier: [any Renderable]] = [:]
	var nonCachable: [any Renderable] = []
	var instructions: [DrawInstruction] = []
	var shouldUpdate: Bool = false

	private var objectCount: Int = 0
	var count: Int { objectCount }

	var requiredBufferSize: Int {
		count * MemoryLayout<InstanceUniforms>.stride
	}

	var buffer: MTLBuffer? = nil
	func allocBuffer(device: any MTLDevice) {
		let size = requiredBufferSize
		guard size > 0 else { return }
		if let buffer = buffer, buffer.length >= size { return }
		buffer = device.makeBuffer(length: size)
	}

	public func append<T: Renderable>(_ objects: [T]) {
		guard !objects.isEmpty else { return }
		shouldUpdate = true
		objectCount += objects.count

		if T.cachable {
			let id = ObjectIdentifier(T.self)
			if cachable[id] == nil {
				cachable[id] = []
			}
			cachable[id]?.append(contentsOf: objects)
		} else {
			nonCachable.append(contentsOf: objects)
		}
	}

	public func removeAll() {
		shouldUpdate = true
		objectCount = 0

		for index in cachable.values.indices {
			cachable.values[index].removeAll(keepingCapacity: true)
		}
		nonCachable.removeAll(keepingCapacity: true)
	}

	func renderInfo(cache: MeshCache) -> (MTLBuffer, [DrawInstruction])? {
		createDrawInstructions(cache: cache)
		guard let buffer = buffer else { return nil }
		return (buffer, instructions)
	}

	func createDrawInstructions(cache: MeshCache) {
		guard shouldUpdate else { return }
		allocBuffer(device: cache.device)
		guard let buffer else { return }

		shouldUpdate = false
		instructions.removeAll(keepingCapacity: true)

		var offset = 0
		for objects in cachable.values {
			guard let first = objects.first else { continue }
			let mesh = cache.mesh(for: first)
			instructions.append((mesh, offset, objects.count))
			offset += buffer.write(objects, offset: offset, transform: (\.uniform))

		}

		guard !nonCachable.isEmpty else { return }

		for (index, object) in nonCachable.enumerated() {
			let mesh = cache.mesh(for: object)
			let instanceOffset = offset + index * MemoryLayout<InstanceUniforms>.stride
			instructions.append((mesh, instanceOffset, 1))
		}
		offset += buffer.write(nonCachable, offset: offset, transform: (\.uniform))
	}
}
