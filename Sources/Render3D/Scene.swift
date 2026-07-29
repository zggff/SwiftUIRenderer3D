import Metal
import Observation
import Render3DShaders
import simd

public final class Scene3D {
	public init(renderGroups: [RenderGroup] = [.opaque, .transparent]) {
		self.renderGroups = renderGroups
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

	public func draw(_ content: (Context) -> Void) {
		removeAll()
		let context = Context(scene: self)
		content(context)
		finishDeclaration()
	}

	public func storage(for id: RenderGroup.ID) -> ObjectStorage? {
		return self.renderGroups.first(where: { n in n.id == id })?.storage
	}

	public struct Context {
		fileprivate var scene: Scene3D

		public func draw(_ objects: [any InstancedRenderable]) {
			scene.storage(for: .opaque)?.append(objects.filter(\.opaque))
			scene.storage(for: .transparent)?.append(objects.filter(\.transparent))
		}
		public func draw(_ object: any InstancedRenderable) {
			draw([object])
		}

		public func draw(_ objects: [any Renderable], in id: RenderGroup.ID) {
			scene.storage(for: id)?.append(objects)
		}
		public func draw(_ object: any Renderable, in id: RenderGroup.ID) {
			draw([object], in: id)
		}

	}
}
