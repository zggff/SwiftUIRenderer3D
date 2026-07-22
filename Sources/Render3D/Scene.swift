import Metal
import Observation
import Render3DShaders
import simd

public typealias DrawInstruction = (Mesh, Int, Int)

@Observable
public final class Scene3D {
	public var version = 0

	public init() {
	}

	private var objects: [ObjectIdentifier: [any Renderable]] = [:]
	private var objectsNonCachable: [any Renderable] = []

	private var meshCache: [ObjectIdentifier: Mesh] = [:]
	private var types: [ObjectIdentifier: Renderable.Type] = [:]

	private var drawInstructions: [DrawInstruction] = []
	private var shouldRecount = false

	private var instancesBuffer: MTLBuffer? = nil

	public var instanceCount: Int {
		return objects.values.map(\.count).reduce(0, +) + objectsNonCachable.count
	}

	public struct Context {
		fileprivate var scene: Scene3D

		public func append<T: Renderable>(objects: [T]) {
			scene.append(objects: objects)
		}
	}

	public func finishDeclaration() {
		version += 1
	}

	public var uniforms: SceneUniforms {
		SceneUniforms(
			lightDirection: [0, 1, 0],
            lightColor: [1, 1, 1],
			diffuseStrength: 0.0,
			ambientStrength: 0.8
		)
	}

	public func draw(_ content: (Context) -> Void) {
		removeAll()
		let context = Context(scene: self)
		content(context)
		finishDeclaration()
	}

	public func append<T: Renderable>(objects: [T]) {
		self.shouldRecount = true
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

	public func removeAll() {
		self.shouldRecount = true
		self.objects = [:]
		self.objectsNonCachable = []
	}

	public func cleanup() {
		self.shouldRecount = true
		self.meshCache = [:]
	}

	private func recalculate(for device: any MTLDevice) {
		self.drawInstructions.removeAll()
		var offset = 0
		for (key, objects) in objects {
			let instances = objects.map(\.uniform)
			let byteCount = objects.count * MemoryLayout<InstanceUniforms>.stride
			let destination = instancesBuffer!.contents().advanced(by: offset)
			instances.withUnsafeBufferPointer { pointer in
				_ = memcpy(destination, pointer.baseAddress, byteCount)
			}
			if meshCache[key] == nil {
				meshCache[key] = objects.first!.mesh(for: device)
			}
			drawInstructions.append((meshCache[key]!, offset, objects.count))
			offset += byteCount
		}
		guard objectsNonCachable.count > 0 else { return }

		let instances = objectsNonCachable.map(\.uniform)
		let byteCount = objectsNonCachable.count * MemoryLayout<InstanceUniforms>.stride
		let destination = instancesBuffer!.contents().advanced(by: offset)
		instances.withUnsafeBufferPointer { pointer in
			_ = memcpy(destination, pointer.baseAddress, byteCount)
		}

		for (i, object) in objectsNonCachable.enumerated() {
			let mesh = object.mesh(for: device)
			drawInstructions.append((mesh, offset + i * MemoryLayout<InstanceUniforms>.stride, 1))
		}
	}

	public func renderInfo(for device: any MTLDevice) -> (MTLBuffer, [DrawInstruction])? {
		guard instanceCount > 0 else {
			return nil
		}
		if !shouldRecount, let instancesBuffer {
			return (instancesBuffer, drawInstructions)
		}

		shouldRecount = false
		let totalBufferSize = instanceCount * MemoryLayout<InstanceUniforms>.stride
		if (instancesBuffer?.length ?? 0) < totalBufferSize {
			instancesBuffer = device.makeBuffer(length: totalBufferSize)!
		}

		recalculate(for: device)
		return (instancesBuffer!, self.drawInstructions)
	}
}
