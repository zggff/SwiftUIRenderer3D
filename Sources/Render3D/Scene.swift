public final class Scene3D {
	public init() {}

	public func withGroup<G: AnyRenderGroup>(_ id: RenderGroupIdentity<G>) -> Self {
        self.renderGroups.append(G())
        return self
	}

	public private(set) var renderGroups: [any AnyRenderGroup] = []

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
			g.removeAll()
		}
	}

	public var drawCallback: ((Context) throws -> Void)? = nil

	/// draws the scene. This allows the renderer to also report errors with drawing
	public func executeDraw() throws {
		guard let drawCallback else { return }

		removeAll()
		let context = Context(scene: self)
		try drawCallback(context)
		self.drawCallback = nil
	}

	public func group<G: AnyRenderGroup>(for identity: RenderGroupIdentity<G>) -> G? {
		renderGroups.first(where: { g in
			ObjectIdentifier(type(of: g)) == ObjectIdentifier(G.self)
		}) as? G
	}

	public func storage<G: AnyRenderGroup>(for identity: RenderGroupIdentity<G>) -> G.Storage? {
		return group(for: identity)?.storage
	}

	/// prepares the scene for drawing but does not actually execute the passed closure
	public func draw(_ content: @escaping (Context) throws -> Void) {
		drawCallback = content
		finishDeclaration()
	}

	public struct Context {
		fileprivate var scene: Scene3D
		public typealias Renderable = UniformProvider & MeshProvider

		/// initialise a drawBuilder with objects
		public func draw<T: Renderable>(_ objects: [T]) -> DrawBuilder<T> {
			DrawBuilder(context: self, objects: objects)
		}

		/// initialise a drawBuilder with objects
		public func draw<T: Renderable>(_ objects: T...) -> DrawBuilder<T> {
			DrawBuilder(context: self, objects: objects)
		}

		public struct DrawBuilder<T: Renderable> {
			fileprivate let context: Context
			fileprivate var objects: [T]

			/// submit Renderable objects to object storage
            @discardableResult
			public func `in`<G: AnyRenderGroup>(_ identity: RenderGroupIdentity<G>) throws -> DrawBuilder
			where T.UniformType == G.Storage.UniformType {
				guard let storage = context.scene.storage(for: identity) else {
					throw RenderError.scene(.noRenderGroup(String(describing: identity)))
				}
				try storage.append(objects: objects)
                return self
			}
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
