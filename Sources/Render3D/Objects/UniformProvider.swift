import Metal
import Render3DShaders
import Synchronization
import simd

public protocol UniformProvider<UniformType> {
	associatedtype UniformType
	func uniform() -> UniformType
}

public protocol MeshProvider<MeshType> {
    associatedtype MeshType: MeshSource
	func getMesh() throws -> MeshType
	var meshId: MeshID { get }
	var cachable: Bool { get }
}

extension MeshProvider {
	public var cachable: Bool {
		true
	}
}

public protocol InstancedRenderable: UniformProvider<Uniforms.Instance> & MeshProvider {
	var model: Matrix { get }
	var vertexColorType: Uniforms.VertexColorType { get }
	var color: Vec4 { get }
}

extension InstancedRenderable {
	public var vertexColorType: Uniforms.VertexColorType { .ignore }
	public func uniform() -> Uniforms.Instance {
		var uniform = Uniforms.Instance()
		uniform.model = model
		uniform.color = color
		uniform.vertexColorType = vertexColorType.rawValue
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
