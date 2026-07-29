import Metal
import Render3DShaders
import Synchronization
import simd

public protocol Renderable {
	func mesh(for device: MTLDevice) throws -> Mesh?
	var meshId: MeshID { get }
	var cachable: Bool { get }
}

extension Renderable {
	public var cachable: Bool {
		true
	}
}

public protocol InstanceUniformProvider: Renderable {
	var model: Matrix { get }
	var color: Vec4 { get }
}

extension Uniforms.Instance {
	public static func from(_ item: any Renderable) throws -> Self {
		guard let item = item as? any InstanceUniformProvider else {
			throw RenderError.uniform(
				expected: (any InstanceUniformProvider).self,
				from: type(of: item)
			)
		}
		return item.uniform()
	}
}

extension InstanceUniformProvider {
	public var opaque: Bool { color.w == 1 }
	public var transparent: Bool { color.w < 1 }

	public func uniform() -> Uniforms.Instance {
		var uniform = Uniforms.Instance()
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

}
