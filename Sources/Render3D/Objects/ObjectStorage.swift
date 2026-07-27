import Metal

public protocol ObjectStorage: AnyObject {
	init()

	var count: Int { get }
	func append<T: Renderable>(_ objects: [T])
	func removeAll()
	func renderInfo(cache: MeshCache) -> (MTLBuffer, [DrawInstruction])?

	func updateBuffers(device: MTLDevice, camera: Camera, scene: Scene3D)
	func bindBuffers(to encoder: MTLRenderCommandEncoder)
}

public class CachedObjectStorage: ObjectStorage {
	public func updateBuffers(device: MTLDevice, camera: Camera, scene: Scene3D) {
		let camera = camera.uniform
		camera.allocateAndWrite(for: device, buffer: &cameraBuffer)
		scene.getSceneUniform(of: SceneUniform.self)?.allocateAndWrite(
			for: device, buffer: &sceneBuffer)
	}

	public func bindBuffers(to encoder: MTLRenderCommandEncoder) {
		encoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
		encoder.setFragmentBuffer(cameraBuffer, offset: 0, index: 1)
		encoder.setVertexBuffer(sceneBuffer, offset: 0, index: 2)
		encoder.setFragmentBuffer(sceneBuffer, offset: 0, index: 2)
	}

	typealias Element = any Renderable3D

	var cachable: [ObjectIdentifier: [Element]] = [:]
	var nonCachable: [Element] = []
	var instructions: [DrawInstruction] = []
	var shouldUpdate: Bool = false
	public private(set) var count: Int = 0
	var buffer: MTLBuffer? = nil

	var cameraBuffer: MTLBuffer? = nil
	var sceneBuffer: MTLBuffer? = nil

	var requiredBufferSize: Int {
		count * MemoryLayout<InstanceUniform>.stride
	}

	public required init() {}

	func allocBuffer(device: MTLDevice) {
		let size = requiredBufferSize
		guard size > 0 else { return }
		if let buffer = buffer, buffer.length >= size { return }
		buffer = device.makeBuffer(length: size)
	}

	public func append<T: Renderable>(_ objects: [T]) {
		guard !objects.isEmpty else { return }
		guard let objects = objects as? [Element] else { return }
		shouldUpdate = true
		count += objects.count

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
		count = 0

		for index in cachable.values.indices {
			cachable.values[index].removeAll(keepingCapacity: true)
		}
		nonCachable.removeAll(keepingCapacity: true)
	}

	public func renderInfo(cache: MeshCache) -> (MTLBuffer, [DrawInstruction])? {
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
			let instanceOffset = offset + index * MemoryLayout<InstanceUniform>.stride
			instructions.append((mesh, instanceOffset, 1))
		}
		offset += buffer.write(nonCachable, offset: offset, transform: (\.uniform))
	}
}
