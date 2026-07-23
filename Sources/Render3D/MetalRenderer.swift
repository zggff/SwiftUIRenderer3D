import Metal
import Render3DShaders

public class MetalRenderer {
	public let device: MTLDevice!
	var commandQueue: MTLCommandQueue!
	let pipeline: MTLRenderPipelineState
	let depthState: MTLDepthStencilState
	let oitHandler: OITTransparencyHandler

	var sceneBuffer: MTLBuffer
	var cameraBuffer: MTLBuffer
	var depthTexture: MTLTexture?

	public init(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
		self.device = device
		self.commandQueue = device.makeCommandQueue()

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

		self.oitHandler = OITTransparencyHandler(device: device, colorPixelFormat: .bgra8Unorm)
		self.cameraBuffer = CameraUniforms.allocateBuffer(for: device)!
		self.sceneBuffer = SceneUniforms.allocateBuffer(for: device)!
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
		viewportSize: CGSize,
		renderPassDescriptor: MTLRenderPassDescriptor,
		commandBuffer: MTLCommandBuffer
	) {
		updateDepthTexture(size: viewportSize)
		guard let depthTexture else { return }

		let aspect = Float(viewportSize.width) / Float(viewportSize.height)

		renderPassDescriptor.depthAttachment.texture = depthTexture
		renderPassDescriptor.depthAttachment.clearDepth = 1.0
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.depthAttachment.storeAction = .store

		guard
			let renderEncoder = commandBuffer.makeRenderCommandEncoder(
				descriptor: renderPassDescriptor)
		else { return }

		renderEncoder.setRenderPipelineState(pipeline)

		if let (instancesBuffer, instructions) = scene.renderInfoOpaque() {
			camera.uniforms(for: aspect).write(into: cameraBuffer)
			scene.uniforms.write(into: sceneBuffer)

			renderEncoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
			renderEncoder.setVertexBuffer(sceneBuffer, offset: 0, index: 2)

			renderEncoder.setFragmentBuffer(cameraBuffer, offset: 0, index: 1)
			renderEncoder.setFragmentBuffer(sceneBuffer, offset: 0, index: 2)

			renderEncoder.setDepthStencilState(depthState)
			for (mesh, offset, count) in instructions {
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
		oitHandler.draw(
			commandBuffer: commandBuffer,
			renderPassDescriptor: renderPassDescriptor,
			viewportSize: viewportSize,
			scene: scene,
			cameraPosition: camera.position,
			cameraBuffer: cameraBuffer,
			sceneBuffer: sceneBuffer,
			depthTexture: depthTexture
		)
	}
}
