import Metal
import Observation
import Render3DShaders
import simd

public final class Scene3D {
	public init() {}
	public private(set) var renderGroups: [RenderGroup] = [
		RenderGroup(id: "builtin.opaque", order: 0, renderer: OpaqueRenderer.self),
		RenderGroup(id: "builtin.transparent", order: 100, renderer: TransparentRenderer.self),
	]

	public func addRenderGroup(_ descriptor: RenderGroup) {
		renderGroups.append(descriptor)
	}

	public var uniforms: SceneUniforms = SceneUniforms(
		lightDirection: [0, 1, 0],
		lightColor: [1, 1, 1],
		diffuseStrength: 0.0,
		ambientStrength: 0.8
	)

	private var cache: MeshCache? = nil
	public var device: (any MTLDevice)? = nil {
		didSet {
			guard (device as AnyObject?) !== (oldValue as AnyObject?) else { return }
		}
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

	public func storage(for id: String) -> ObjectStorage? {
		return self.renderGroups.first(where: { n in n.id == id })?.storage
	}

	public struct Context {
		fileprivate var scene: Scene3D

		public func draw<T: Renderable>(_ objects: [T]) {
			scene.storage(for: "builtin.opaque")?.append(objects.filter(\.opaque))
			scene.storage(for: "builtin.transparent")?.append(objects.filter(\.transparent))
		}
		public func draw<T: Renderable>(_ object: T) {
			draw([object])
		}

		public func draw<T: Renderable>(_ objects: [T], in id: String) {
			scene.storage(for: id)?.append(objects)
		}
		public func draw<T: Renderable>(_ object: T, in id: String) {
			draw([object])
		}

	}
}
