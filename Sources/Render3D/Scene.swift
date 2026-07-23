import Metal
import Observation
import Render3DShaders
import simd

public typealias DrawInstruction = (Mesh, Int, Int)

@Observable
public final class Scene3D {
	public init() {}

	public var version = 0
	public var uniforms: SceneUniforms {
		SceneUniforms(
			lightDirection: [0, 1, 0],
			lightColor: [1, 1, 1],
			diffuseStrength: 0.0,
			ambientStrength: 0.8
		)
	}

	private var _device: (any MTLDevice)? = nil
	public var device: (any MTLDevice)? {
		get {
			_device
		}
		set {
			let isNew =
				switch (self._device, newValue) {
					case (let deviceOld?, let deviceNew?):
						ObjectIdentifier(deviceOld as AnyObject)
							!= ObjectIdentifier(deviceNew as AnyObject)
					case (nil, nil): false
					default: true
				}
			if isNew {
				self._buffer = nil
				self._device = newValue
				self.meshCache = [:]
			}
		}
	}

	private var objects: [ObjectIdentifier: [any Renderable]] = [:]
	private var objectsNonCachable: [any Renderable] = []
	private var objectsTransparent: [any Renderable] = []

	private var meshCache: [ObjectIdentifier: Mesh] = [:]
	private var types: [ObjectIdentifier: Renderable.Type] = [:]

	private var drawInstructions: [DrawInstruction] = []
	private var shouldUpdate = false

	public var countOpaque: Int {
		return objects.values.map(\.count).reduce(0, +) + objectsNonCachable.count
	}
	public var countTransparent: Int {
		objectsTransparent.count
	}
	public var count: Int {
		countOpaque + countTransparent
	}

	private var _buffer: MTLBuffer? = nil
	private var buffer: MTLBuffer {
		let size = count * MemoryLayout<InstanceUniforms>.stride
		if _buffer?.length ?? 0 < size {
			_buffer = device!.makeBuffer(length: size)
		}
		return _buffer!
	}

	private func mesh(_ device: MTLDevice, _ obj: any Renderable) -> Mesh {
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

	public func finishDeclaration() {
		version += 1
	}

	public func append<T: Renderable>(objects: [T]) {
		self.shouldUpdate = true
		if T.cachable {
			let id = ObjectIdentifier(T.self)
			if self.objects[id] == nil {
				self.objects[id] = []
				self.types[id] = T.self
			}
			self.objects[id]?.append(contentsOf: objects)
		} else {
			self.objectsNonCachable.append(contentsOf: objects)
		}
	}

	public func appendTransparent<T: Renderable>(objects: [T]) {
		self.objectsTransparent.append(contentsOf: objects)
	}

	public func removeAll() {
		self.shouldUpdate = true
		self.objects = [:]
		self.objectsNonCachable = []
	}

	public func cleanup() {
		self.shouldUpdate = true
		self.meshCache = [:]
	}

	private func update() {
		guard let device else { return }

		self.drawInstructions.removeAll()
		var offset = 0
		for objects in objects.values {
			drawInstructions.append((mesh(device, objects.first!), offset, objects.count))
			offset += objects.map(\.uniform).write(into: buffer, offset: offset)
		}
		guard objectsNonCachable.count > 0 else { return }

		_ = objectsNonCachable.map(\.uniform).write(into: buffer, offset: offset)
		for (i, object) in objectsNonCachable.enumerated() {
			let mesh = object.mesh(for: device)
			drawInstructions.append((mesh, offset + i * MemoryLayout<InstanceUniforms>.stride, 1))
		}
	}

	func renderInfoOpaque() -> (MTLBuffer, [DrawInstruction])? {
		guard let _ = device else {
			fatalError("device must be set")
		}

		guard count > 0 else {
			return nil
		}
		if !shouldUpdate {
			return (buffer, drawInstructions)
		}

		shouldUpdate = false
		update()
		return (buffer, self.drawInstructions)
	}

	func renderInfoTransparent() -> (MTLBuffer, [DrawInstruction])? {
		guard let device else {
			fatalError("device must be set")
		}

		guard countTransparent > 0 else {
			return nil
		}

		let offset = countOpaque * MemoryLayout<InstanceUniforms>.stride
		let instances = objectsTransparent.map(\.uniform)
		_ = instances.write(into: buffer, offset: offset)

		let instructions = objectsTransparent.enumerated().map { (i, obj) in
			(mesh(device, obj), offset + i * MemoryLayout<InstanceUniforms>.stride, 1)
		}

		return (buffer, instructions)
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
			scene.append(objects: objects)
		}
		public func draw<T: Renderable>(_ object: T) {
			scene.append(objects: [object])
		}
		public func drawTransparent<T: Renderable>(_ objects: [T]) {
			scene.appendTransparent(objects: objects)
		}
	}

}
