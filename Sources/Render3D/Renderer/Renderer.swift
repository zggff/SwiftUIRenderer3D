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

	let cameraBuffer: MTLBuffer
	let sceneBuffer: MTLBuffer
	let cache: MeshCache

	public func bindSharedBuffers(to encoder: MTLRenderCommandEncoder) {
		encoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
		encoder.setFragmentBuffer(cameraBuffer, offset: 0, index: 1)
		encoder.setVertexBuffer(sceneBuffer, offset: 0, index: 2)
		encoder.setFragmentBuffer(sceneBuffer, offset: 0, index: 2)
	}
}

public typealias DrawInstruction = (Mesh?, Int, Int)

class MeshCache {
	var meshCache: [ObjectIdentifier: Mesh] = [:]
	var device: any MTLDevice

	init(device: MTLDevice) {
		self.device = device
	}

	func mesh(for obj: any Renderable) -> Mesh? {
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

	var renderGroups: [RenderGroup] = []
	var size: CGSize = CGSize(width: 1, height: 1)

	public required init(device: any MTLDevice) {
		self.device = device
		self.cameraBuffer = CameraUniforms.allocateBuffer(for: device)!
		self.sceneBuffer = SceneUniforms.allocateBuffer(for: device)!
		self.meshCache = MeshCache(device: device)
	}

	public func update(drawableSize size: CGSize) {
		updateDepthTexture(size: size)
		self.size = size
		for g in renderGroups {
			g.renderer?.update(drawableSize: size)
		}
	}

	public func initRenderers(scene: Scene3D) throws {
		for g in scene.renderGroups {
			if g.renderer == nil {
                g.renderer = try? g.rendererType.init(device: device)
				g.renderer?.update(drawableSize: size)
			}
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
		try initRenderers(scene: scene)

		guard let depthTexture else { return }

		let aspect = Float(size.width) / Float(size.height)
		camera.uniforms(for: aspect).write(into: cameraBuffer)
		scene.uniforms.write(into: sceneBuffer)

		let context = RenderContext(
			scene: scene, camera: camera, renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer, depthTexture: depthTexture,
			cameraBuffer: cameraBuffer, sceneBuffer: sceneBuffer,
			cache: meshCache)

		for g in scene.renderGroups.sorted(by: { a, b in a.order < b.order }) {
			g.renderer?.draw(context: context, group: g)
		}
	}
}
