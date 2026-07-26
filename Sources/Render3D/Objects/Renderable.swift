import Metal
import Render3DShaders
import Synchronization
import simd

public protocol Renderable {
	var model: Matrix { get }
	var color: Vec4 { get }
	var center: Vec3 { get }
	var uniform: InstanceUniforms { get }

	func mesh(for device: MTLDevice) -> Mesh?
	static var cachable: Bool { get }
}

extension Renderable {
    public var opaque: Bool {color.w == 1}
    public var transparent: Bool {color.w < 1}

	public var uniform: InstanceUniforms {
		var uniforms = InstanceUniforms()
		uniforms.model = model
		uniforms.color = color
		uniforms.normal = float3x3(
			columns: (
				Vec3(model.columns.0.x, model.columns.0.y, model.columns.0.z),
				Vec3(model.columns.1.x, model.columns.1.y, model.columns.1.z),
				Vec3(model.columns.2.x, model.columns.2.y, model.columns.2.z)
			))
		uniforms.shininess = 10
		return uniforms
	}

	public static var cachable: Bool {
		true
	}
}
