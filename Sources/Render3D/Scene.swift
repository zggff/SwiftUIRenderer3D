import Metal
import Observation
import Render3DShaders
import simd

public final class Scene3D {
	public init(
		renderGroups: [RenderGroup] = [.opaque, .transparent],
		additionalRenderGroups: [RenderGroup] = []
	) {
		self.renderGroups = renderGroups
		self.renderGroups.append(contentsOf: additionalRenderGroups)
	}

	public private(set) var renderGroups: [RenderGroup]

	public func addRenderGroup(_ descriptor: RenderGroup) {
		renderGroups.append(descriptor)
	}

	public var uniforms: [ObjectIdentifier: any Uniform] = [
		ObjectIdentifier(Uniforms.SceneLight.self):
			Uniforms.SceneLight(
				lightDirection: [0, 1, 0],
				lightColor: [1, 1, 1],
				diffuseStrength: 0.0,
				ambientStrength: 0.8
			)
	]

	public func setSceneUniform<T: Uniform>(_ uniform: T) {
		self.uniforms[ObjectIdentifier(T.self)] = uniform
	}

	public func getSceneUniform<T: Uniform>(of type: T.Type) -> T? {
		return self.uniforms[ObjectIdentifier(type)] as? T
	}

	public func modifySceneUniform<T: Uniform>(of type: T.Type, _ modifier: (inout T) -> Void) {
		guard var uniform = getSceneUniform(of: type) else { return }
		modifier(&uniform)
		setSceneUniform(uniform)
	}

	public var onFinishDeclaration: (() -> Void)?
	public func finishDeclaration() {
		onFinishDeclaration?()
	}

	public func removeAll() {
		for g in renderGroups {
			g.storage.removeAll()
		}
	}

	public func draw(_ content: (Context) throws -> Void) rethrows {
		removeAll()
		let context = Context(scene: self)
		try content(context)
		finishDeclaration()
	}

	public struct Context {
		fileprivate var scene: Scene3D

		public func draw(_ objects: [any UniformProvider & MeshProvider], in id: RenderGroup.ID)
			throws
		{
			guard let group = scene.renderGroups.first(where: { g in g.id == id }) else {
				throw RenderError.scene(.noRenderGroup(id))
			}
			try group.storage.append(typeErased: objects)
		}
	}
}

protocol RenderableCollection {
	var renderables: [any MeshProvider] { get }
}

extension Array: RenderableCollection where Element == any MeshProvider {
	var renderables: [any MeshProvider] { self }
}

extension MeshProvider {
	var renderables: [any MeshProvider] { [self] }
}

func cast<T>(_ value: Any, to type: T.Type) -> T? {
	return value as? T
}
