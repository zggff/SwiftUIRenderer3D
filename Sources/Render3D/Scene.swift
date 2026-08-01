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

	public var drawCallback: ((Context) throws -> Void)? = nil

	/// draws the scene. This allows the renderer to also report errors with drawing
	public func executeDraw() throws {
		guard let drawCallback else { return }

		removeAll()
		let context = Context(scene: self)
		try drawCallback(context)
        self.drawCallback = nil
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

		public struct DrawBuilder<T: Renderable> {
			fileprivate let context: Context
			fileprivate var objects: [T]

			/// submit Renderable objects to object storage
			public func `in`(_ id: RenderGroup.ID) throws {
				guard let group = context.scene.renderGroups.first(where: { g in g.id == id })
				else {
					throw RenderError.scene(.noRenderGroup(id))
				}
				guard let storage = group.storage as? any ObjectStorage<T.UniformType> else {
                    throw RenderError.scene(.invalidStorage)
				}
				try storage.append(objects: objects)
			}

			/// submit Renderable objects to object storage
			public func `in`(_ ids: RenderGroup.ID...) throws {
				for id in ids {
					try self.in(id)
				}
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
