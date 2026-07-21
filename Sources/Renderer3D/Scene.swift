import SharedShaderTypes
import SwiftUI
import simd

public typealias DrawInstruction = (Mesh, Int, Int)

@Observable
public final class Scene3D {
	var version = 0

	public init() {
	}

	private var objects: [ObjectIdentifier: [any Renderable]] = [:]
	private var meshCache: [ObjectIdentifier: Mesh] = [:]
	private var types: [ObjectIdentifier: Renderable.Type] = [:]

	private var drawInstructions: [DrawInstruction] = []
	private var shouldRecount = false

	private var _instancesBuffer: MTLBuffer? = nil

	public var instanceCount: Int {
		return objects.values.map(\.count).reduce(0, +)
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

	public func draw(_ content: (Context) -> Void) {
        removeAll()
		let context = Context(scene: self)
		content(context)
        finishDeclaration()
	}

	public func append<T: Renderable>(objects: [T]) {
		self.shouldRecount = true
		let id = ObjectIdentifier(T.self)
		if self.objects[id] == nil {
			self.objects[id] = []
			self.types[id] = T.self
		}
		self.objects[id]?.append(contentsOf: objects)
	}

	public func remove<T: Renderable>(_: T.Type) {
		self.shouldRecount = true
		let id = ObjectIdentifier(T.self)
		objects[id]?.removeAll()
	}

	public func removeAll() {
		self.shouldRecount = true
		self.objects = [:]
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
			let destination = _instancesBuffer!.contents().advanced(by: offset)
			instances.withUnsafeBufferPointer { pointer in
				_ = memcpy(destination, pointer.baseAddress, byteCount)
			}
			if meshCache[key] == nil {
				meshCache[key] = types[key]!.mesh(for: device)
			}
			drawInstructions.append((meshCache[key]!, offset, objects.count))
			offset += byteCount
		}
	}

	public func instancesBuffer(for device: any MTLDevice) -> (MTLBuffer, [DrawInstruction])? {
		guard instanceCount > 0 else {
			return nil
		}
		if !shouldRecount, let buffer = _instancesBuffer {
			return (buffer, drawInstructions)
		}

		shouldRecount = false
		let totalBufferSize = instanceCount * MemoryLayout<InstanceUniforms>.stride
		if (_instancesBuffer?.length ?? 0) < totalBufferSize {
			_instancesBuffer = device.makeBuffer(length: totalBufferSize)!
		}

		recalculate(for: device)
		return (_instancesBuffer!, self.drawInstructions)
	}
}
