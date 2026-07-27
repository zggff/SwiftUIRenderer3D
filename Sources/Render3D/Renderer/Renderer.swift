import Metal

public protocol MetalRenderer: AnyObject {
	init(device: any MTLDevice) throws
	func update(drawableSize size: CGSize)
	func draw(context: RenderContext, group: RenderGroup)
}

public struct RenderContext {
	public let scene: Scene3D
	public let camera: Camera
	public let renderPassDescriptor: MTLRenderPassDescriptor
	public let commandBuffer: MTLCommandBuffer
	public let depthTexture: MTLTexture

	public let cameraBuffer: MTLBuffer
	public let sceneBuffer: MTLBuffer
	public let cache: MeshCache

	public func bindSharedBuffers(to encoder: MTLRenderCommandEncoder) {
		encoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
		encoder.setFragmentBuffer(cameraBuffer, offset: 0, index: 1)
		encoder.setVertexBuffer(sceneBuffer, offset: 0, index: 2)
		encoder.setFragmentBuffer(sceneBuffer, offset: 0, index: 2)
	}
}

public typealias DrawInstruction = (Mesh?, Int, Int)

public class MeshCache {
	var meshCache: [ObjectIdentifier: Mesh] = [:]
	public private(set) var device: any MTLDevice

	init(device: MTLDevice) {
		self.device = device
	}

	public func mesh(for obj: any Renderable) -> Mesh? {
		let objType = type(of: obj)
		guard objType.cachable else {
			return obj.mesh(for: device)
		}
		let id = ObjectIdentifier(objType)
		guard let mesh = meshCache[id] else {
			let mesh = obj.mesh(for: device)
			meshCache[id] = mesh
			return mesh
		}
		return mesh
	}
}

public class Renderer {
	let device: any MTLDevice
	var sceneBuffer: MTLBuffer
	var cameraBuffer: MTLBuffer
	var depthTexture: MTLTexture?
	var meshCache: MeshCache

	var renderers: [String: (any MetalRenderer)] = [:]
	var size: CGSize = CGSize(width: 1, height: 1)

	public struct Error: Swift.Error, LocalizedError {
		public let id: String
		public let error: Swift.Error
		public var errorDescription: String? {
			return "[\(id)] \(error.localizedDescription)"
		}
	}

	public required init(device: any MTLDevice) {
		self.device = device
		self.cameraBuffer = CameraUniform.allocateBuffer(for: device)!
		self.sceneBuffer = SceneUniform.allocateBuffer(for: device)!
		self.meshCache = MeshCache(device: device)
	}

	public func prepare(for scene: Scene3D) throws {
		for g in scene.renderGroups {
			if renderers[g.id] == nil {
				do { renderers[g.id] = try g.rendererType.init(device: device) } catch {
					throw Self.Error(id: g.id, error: error)
				}
			}
		}
	}

	public func prepared(for scene: Scene3D) -> Bool {
		return scene.renderGroups.allSatisfy({ g in renderers.keys.contains(g.id) })
	}

	public func update(drawableSize size: CGSize) {
		updateDepthTexture(size: size)
		self.size = size
		for renderer in renderers.values {
			renderer.update(drawableSize: size)
		}
	}

	private func updateDepthTexture(size: CGSize) {
		let width = Int(size.width)
		let height = Int(size.height)
		guard width > 0 && height > 0 else { return }

		if depthTexture?.width != width || depthTexture?.height != height {
			let desc = MTLTextureDescriptor()
			desc.textureType = .type2D
			desc.pixelFormat = .depth32Float
			desc.width = width
			desc.height = height
			desc.storageMode = .private
			desc.usage = [.renderTarget, .shaderRead]
			depthTexture = device.makeTexture(descriptor: desc)
		}
	}

	public func draw(
		scene: Scene3D,
		camera: Camera,
		renderPassDescriptor: MTLRenderPassDescriptor,
		commandBuffer: MTLCommandBuffer,
	) throws {
		try prepare(for: scene)
		update(drawableSize: size)

		guard let depthTexture else { return }

		let aspect = Float(size.width) / Float(size.height)
		camera.uniform(for: aspect).write(into: cameraBuffer)
		scene.uniform.write(into: sceneBuffer)

		renderPassDescriptor.depthAttachment.texture = depthTexture
		renderPassDescriptor.depthAttachment.clearDepth = 1.0
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.depthAttachment.storeAction = .store
		renderPassDescriptor.depthAttachment.loadAction = .clear

		renderPassDescriptor.colorAttachments[0].loadAction = .clear

		let context = RenderContext(
			scene: scene, camera: camera, renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer, depthTexture: depthTexture,
			cameraBuffer: cameraBuffer, sceneBuffer: sceneBuffer,
			cache: meshCache)

		for g in scene.renderGroups.sorted(by: { a, b in a.order < b.order }) {
			guard let renderer = renderers[g.id] else { continue }
			renderer.draw(context: context, group: g)
			renderPassDescriptor.colorAttachments[0].loadAction = .load
			renderPassDescriptor.depthAttachment.loadAction = .load
		}
	}
}
