import SharedShaderTypes
import SwiftUI
import simd

public typealias DrawInstruction = (Renderable.Type, Int, Int)

public class Scene3D: Observable {
	var onContentChanged: (() -> Void)?

	public init() {
	}

	var objects: [ObjectIdentifier: [any Renderable]] = [:]
	var meshes: [ObjectIdentifier: Renderable.Type] = [:]

	private var drawInstructions: [DrawInstruction] = []
	private var shouldRecount = false

	private var _instancesBuffer: MTLBuffer? = nil

	public var instanceCount: Int {
		return objects.values.map(\.count).reduce(0, +)
	}

	public func finishDeclaration() {
		onContentChanged?()
	}

	public func append<T: Renderable>(objects: [T]) {
		self.shouldRecount = true
		let id = ObjectIdentifier(T.self)
		if self.objects[id] == nil {
			self.objects[id] = []
			self.meshes[id] = T.self
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
		for key in self.objects.keys {
			objects[key]?.removeAll()
		}
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
			drawInstructions.append((meshes[key]!, offset, objects.count))
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
