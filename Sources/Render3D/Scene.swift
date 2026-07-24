import Metal
import Observation
import Render3DShaders
import simd

public typealias DrawInstruction = (Mesh?, Int, Int)

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

class MeshCache {
	var meshCache: [ObjectIdentifier: Mesh] = [:]
	var device: any MTLDevice

	init?(for device: MTLDevice?) {
		guard let device = device else { return nil }
		self.device = device
	}

	func mesh(for obj: any Renderable) -> Mesh? {
		let objType = type(of: obj)
		guard objType.cachable else {
			return obj.mesh(for: device)
		}
		let id = ObjectIdentifier(objType)
		guard let mesh = meshCache[id] else {
			let mesh = obj.mesh(for: device)
			meshCache[id] = mesh
			return mesh
		}
		return mesh
	}
}

public final class Scene3D {
	public init() {}

	public let opaque: ObjectStorage = ObjectStorage()
	public let transparent: ObjectStorage = ObjectStorage()

	public var uniforms: SceneUniforms = SceneUniforms(
		lightDirection: [0, 1, 0],
		lightColor: [1, 1, 1],
		diffuseStrength: 0.0,
		ambientStrength: 0.8
	)

	private var cache: MeshCache? = nil
	public var device: (any MTLDevice)? = nil {
		didSet {
			guard (device as AnyObject?) !== (oldValue as AnyObject?) else { return }

			opaque.buffer = nil
			transparent.buffer = nil
			cache = MeshCache(for: device)
		}
	}

	public var count: Int {
		opaque.count + transparent.count
	}

	public var onFinishDeclaration: (() -> Void)?
	public func finishDeclaration() {
		onFinishDeclaration?()
	}

	public func removeAll() {
		self.transparent.removeAll()
		self.opaque.removeAll()
	}

	func renderInfoOpaque() -> (MTLBuffer, [DrawInstruction])? {
		guard let cache else {
			return nil
		}
		opaque.createDrawInstructions(cache: cache)
		guard let buffer = opaque.buffer else { return nil }
		return (buffer, opaque.instructions)
	}

	func renderInfoTransparent() -> (MTLBuffer, [DrawInstruction])? {
		guard let cache else {
			return nil
		}
		transparent.createDrawInstructions(cache: cache)
		guard let buffer = transparent.buffer else { return nil }
		return (buffer, transparent.instructions)
	}

	public func draw(_ content: (Context) -> Void) {
		removeAll()
		let context = Context(scene: self)
		content(context)
		finishDeclaration()
	}

	public struct Context {
		fileprivate var scene: Scene3D

		public func draw<T: Renderable>(_ objects: [T]) {
			scene.opaque.append(objects.filter(\.opaque))
			scene.transparent.append(objects.filter(\.transparent))
		}
		public func draw<T: Renderable>(_ object: T) {
			draw(_: [object])
		}
		public func drawTransparent<T: Renderable>(_ objects: [T]) {
			scene.transparent.append(objects)
		}
		public func drawOpaque<T: Renderable>(_ objects: [T]) {
			scene.opaque.append(objects)
		}
	}
}
