import Metal

protocol MetalRenderer {
	init(device: MTLDevice)
	func update(drawableSize size: CGSize)
	func draw(
		scene: Scene3D,
		camera: Camera,
		renderPassDescriptor: MTLRenderPassDescriptor,
		commandBuffer: MTLCommandBuffer,
		depthTexture: MTLTexture,
		buffers: [(Int, MTLBuffer)]
	)
}

public class Renderer {
	let device: any MTLDevice
	var sceneBuffer: MTLBuffer
	var cameraBuffer: MTLBuffer
	var depthTexture: MTLTexture?

	let opaque: OpaqueRenderer
	let transparent: TransparentRenderer
	var aspect: Float = 1

	public required init(device: any MTLDevice) {
		self.device = device

		self.cameraBuffer = CameraUniforms.allocateBuffer(for: device)!
		self.sceneBuffer = SceneUniforms.allocateBuffer(for: device)!

		self.opaque = OpaqueRenderer(device: device)
		self.transparent = TransparentRenderer(device: device)
	}

	public func update(drawableSize size: CGSize) {
		updateDepthTexture(size: size)
		aspect = Float(size.width) / Float(size.height)
		opaque.update(drawableSize: size)
		transparent.update(drawableSize: size)
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
	) {
		guard let depthTexture else { return }
		camera.uniforms(for: aspect).write(into: cameraBuffer)
		scene.uniforms.write(into: sceneBuffer)
		let buffers = [(1, cameraBuffer), (2, sceneBuffer)]

		opaque.draw(
			scene: scene, camera: camera, renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer, depthTexture: depthTexture, buffers: buffers)
		transparent.draw(
			scene: scene, camera: camera, renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer, depthTexture: depthTexture, buffers: buffers)
	}
}
