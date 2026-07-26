import Metal

public class ObjectStorage {
	var cachable: [ObjectIdentifier: [any Renderable]] = [:]
	var nonCachable: [any Renderable] = []
	var instructions: [DrawInstruction] = []
	var shouldUpdate: Bool = false

	var count: Int {
		cachable.values.map(\.count).reduce(0, +) + nonCachable.count
	}
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
		self.shouldUpdate = true
		if T.cachable {
			let id = ObjectIdentifier(T.self)
			if self.cachable[id] == nil {
				self.cachable[id] = []
			}
			self.cachable[id]?.append(contentsOf: objects)
		} else {
			self.nonCachable.append(contentsOf: objects)
		}
	}

	public func removeAll() {
		self.shouldUpdate = true
		self.cachable.removeAll()
		self.nonCachable.removeAll()
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
		instructions.removeAll()
		var offset = 0
		for objects in cachable.values {
			guard let first = objects.first else { continue }
			let mesh = cache.mesh(for: first)
			instructions.append((mesh, offset, objects.count))
			offset += objects.map(\.uniform).write(into: buffer, offset: offset)
		}
		guard nonCachable.count > 0 else { return }

		nonCachable.map(\.uniform).write(into: buffer, offset: offset)
		for (i, object) in nonCachable.enumerated() {
			let mesh = cache.mesh(for: object)
			instructions.append((mesh, offset + i * MemoryLayout<InstanceUniforms>.stride, 1))
		}
	}
}
