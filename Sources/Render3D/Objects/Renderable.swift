import Metal
import Render3DShaders
import Synchronization
import simd

public protocol Renderable {
	associatedtype UniformType
	var uniform: UniformType { get }

	func mesh(for device: MTLDevice) -> Mesh?
	static var cachable: Bool { get }
}

public protocol Renderable3D: Renderable {
	associatedtype UniformType = InstanceUniform
	var model: Matrix { get }
	var color: Vec4 { get }
}

extension Renderable3D {
	public var opaque: Bool { color.w == 1 }
	public var transparent: Bool { color.w < 1 }

	public var uniform: InstanceUniform {
		var uniform = InstanceUniform()
		uniform.model = model
		uniform.color = color
		uniform.normal = float3x3(
			columns: (
				Vec3(model.columns.0.x, model.columns.0.y, model.columns.0.z),
				Vec3(model.columns.1.x, model.columns.1.y, model.columns.1.z),
				Vec3(model.columns.2.x, model.columns.2.y, model.columns.2.z)
			))
		uniform.shininess = 10
		return uniform
	}

	public static var cachable: Bool {
		true
	}
}
