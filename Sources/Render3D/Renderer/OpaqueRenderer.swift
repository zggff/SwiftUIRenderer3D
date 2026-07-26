import Metal
import Render3DShaders

public class OpaqueRenderer: MetalRenderer {

	public let device: any MTLDevice
	let pipeline: MTLRenderPipelineState
	let depthState: MTLDepthStencilState
	// let oitHandler: OITTransparencyHandler

	public required init(device: any MTLDevice) {
		self.device = device

		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		let library: MTLLibrary
		do {
			library = try device.makeDefaultLibrary(bundle: .render3DShaders)
		} catch {
			fatalError("Failed to load Renderer3D Metal library: \(error)")
		}

		pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexMain")
		pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
		pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
		pipelineDescriptor.vertexDescriptor = Vertex.defaultLayout

		pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
		pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
		pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
		pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
		pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

		self.pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

		let depthDescriptor = MTLDepthStencilDescriptor()
		depthDescriptor.depthCompareFunction = .less
		depthDescriptor.isDepthWriteEnabled = true
		self.depthState = device.makeDepthStencilState(descriptor: depthDescriptor)!

		// self.oitHandler = OITTransparencyHandler(device: device, colorPixelFormat: .bgra8Unorm)
		// self.cameraBuffer = CameraUniforms.allocateBuffer(for: device)!
		// self.sceneBuffer = SceneUniforms.allocateBuffer(for: device)!
	}

	func update(drawableSize size: CGSize) {}

	public func draw(
		scene: Scene3D,
		camera: Camera,
		renderPassDescriptor: MTLRenderPassDescriptor,
		commandBuffer: MTLCommandBuffer,
		depthTexture: MTLTexture,
		buffers: [(Int, MTLBuffer)]

	) {
		// updateDepthTexture(size: viewportSize)
		// guard let depthTexture else { return }

		renderPassDescriptor.depthAttachment.texture = depthTexture
		renderPassDescriptor.depthAttachment.clearDepth = 1.0
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.depthAttachment.storeAction = .store

		guard
			let renderEncoder = commandBuffer.makeRenderCommandEncoder(
				descriptor: renderPassDescriptor)
		else { return }

		renderEncoder.setRenderPipelineState(pipeline)

		renderEncoder.setDepthStencilState(depthState)

		for (index, buffer) in buffers {
			renderEncoder.setVertexBuffer(buffer, offset: 0, index: index)
			renderEncoder.setFragmentBuffer(buffer, offset: 0, index: index)
		}

		if let (instancesBuffer, instructions) = scene.renderInfoOpaque() {
			// renderEncoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
			// renderEncoder.setVertexBuffer(sceneBuffer, offset: 0, index: 2)
			// renderEncoder.setFragmentBuffer(cameraBuffer, offset: 0, index: 1)
			// renderEncoder.setFragmentBuffer(sceneBuffer, offset: 0, index: 2)

			for (mesh, offset, count) in instructions {
				guard let mesh else { continue }
				renderEncoder.setCullMode(mesh.cullMode)
				renderEncoder.setVertexBuffer(mesh.vertex, offset: 0, index: 0)
				renderEncoder.setVertexBuffer(instancesBuffer, offset: offset, index: 3)
				renderEncoder.setFragmentBuffer(instancesBuffer, offset: offset, index: 3)

				renderEncoder.drawIndexedPrimitives(
					type: .triangle, indexCount: mesh.count, indexType: mesh.indexType,
					indexBuffer: mesh.index,
					indexBufferOffset: 0, instanceCount: count)
			}
		}

		renderEncoder.endEncoding()
		// oitHandler.draw(
		// 	commandBuffer: commandBuffer,
		// 	renderPassDescriptor: renderPassDescriptor,
		// 	viewportSize: viewportSize,
		// 	scene: scene,
		// 	cameraPosition: camera.position,
		// 	cameraBuffer: cameraBuffer,
		// 	sceneBuffer: sceneBuffer,
		// 	depthTexture: depthTexture
		// )
	}
}
