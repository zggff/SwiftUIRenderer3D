import Metal
import Render3DShaders
import Synchronization
import simd

public protocol Renderable {
	func mesh(for device: MTLDevice) -> Mesh?
	func uniform<T: Uniform>(of type: T.Type) -> T?
	static var cachable: Bool { get }
}

public protocol Renderable3D: Renderable {
	var model: Matrix { get }
	var color: Vec4 { get }
}

extension Renderable3D {
	public var opaque: Bool { color.w == 1 }
	public var transparent: Bool { color.w < 1 }

	public func uniform<T: Uniform>(of type: T.Type) -> T? {
		if type != InstanceUniform.self {
            return nil
		}
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
		return uniform as? T
	}

	public static var cachable: Bool {
		true
	}
}
