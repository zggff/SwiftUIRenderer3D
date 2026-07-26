import Metal
import Render3DShaders

public class TransparentRenderer: MetalRenderer {
	private let device: MTLDevice
	private var accumTexture: MTLTexture?
	private var revealTexture: MTLTexture?

	private let accumulationPipelineState: MTLRenderPipelineState
	private let compositionPipelineState: MTLRenderPipelineState
	private let depthStateTransparent: MTLDepthStencilState

	public required init(device: MTLDevice) {
		self.device = device

		let library = try! device.makeDefaultLibrary(bundle: .render3DShaders)

		let accumDesc = MTLRenderPipelineDescriptor()
		accumDesc.vertexFunction = library.makeFunction(name: "vertexMain")
		accumDesc.fragmentFunction = library.makeFunction(name: "oitAccumulationFragment")
		accumDesc.depthAttachmentPixelFormat = .depth32Float
		accumDesc.vertexDescriptor = Vertex.defaultLayout

		accumDesc.colorAttachments[0].pixelFormat = .rgba16Float
		accumDesc.colorAttachments[0].isBlendingEnabled = true
		accumDesc.colorAttachments[0].sourceRGBBlendFactor = .one
		accumDesc.colorAttachments[0].destinationRGBBlendFactor = .one
		accumDesc.colorAttachments[0].rgbBlendOperation = .add
		accumDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
		accumDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
		accumDesc.colorAttachments[0].alphaBlendOperation = .add

		accumDesc.colorAttachments[1].pixelFormat = .r16Float
		accumDesc.colorAttachments[1].isBlendingEnabled = true
		accumDesc.colorAttachments[1].sourceRGBBlendFactor = .zero
		accumDesc.colorAttachments[1].destinationRGBBlendFactor = .oneMinusSourceColor
		accumDesc.colorAttachments[1].rgbBlendOperation = .add

		self.accumulationPipelineState = try! device.makeRenderPipelineState(descriptor: accumDesc)

		let compDesc = MTLRenderPipelineDescriptor()
		compDesc.vertexFunction = library.makeFunction(name: "oitCompositeVertex")
		compDesc.fragmentFunction = library.makeFunction(name: "oitCompositeFragment")
		compDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
		compDesc.colorAttachments[0].isBlendingEnabled = true
		compDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
		compDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
		compDesc.colorAttachments[0].rgbBlendOperation = .add
		compDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
		compDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
		compDesc.colorAttachments[0].alphaBlendOperation = .add

		self.compositionPipelineState = try! device.makeRenderPipelineState(descriptor: compDesc)

		let depthDesc = MTLDepthStencilDescriptor()
		depthDesc.depthCompareFunction = .less
		depthDesc.isDepthWriteEnabled = false
		self.depthStateTransparent = device.makeDepthStencilState(descriptor: depthDesc)!
	}

	private func updateTextures(size: CGSize) {
		let width = Int(size.width)
		let height = Int(size.height)
		guard width > 0 && height > 0 else { return }

		if accumTexture?.width != width || accumTexture?.height != height {
			let desc = MTLTextureDescriptor()
			desc.textureType = .type2D
			desc.pixelFormat = .rgba16Float
			desc.width = width
			desc.height = height
			desc.storageMode = .private
			desc.usage = [.renderTarget, .shaderRead]
			accumTexture = device.makeTexture(descriptor: desc)

			desc.pixelFormat = .r16Float
			revealTexture = device.makeTexture(descriptor: desc)
		}
	}

	public func update(drawableSize size: CGSize) {
		updateTextures(size: size)
	}

	public func draw(
		scene: Scene3D,
		camera: Camera,
		renderPassDescriptor: MTLRenderPassDescriptor,
		commandBuffer: MTLCommandBuffer,
		depthTexture: MTLTexture,
		buffers: [(Int, MTLBuffer)]
	) {

		guard let accum = accumTexture, let reveal = revealTexture else { return }

		let pass = MTLRenderPassDescriptor()
		pass.colorAttachments[0].texture = accum
		pass.colorAttachments[0].loadAction = .clear
		pass.colorAttachments[0].storeAction = .store
		pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

		pass.colorAttachments[1].texture = reveal
		pass.colorAttachments[1].loadAction = .clear
		pass.colorAttachments[1].storeAction = .store
		pass.colorAttachments[1].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)

		pass.depthAttachment.texture = depthTexture
		pass.depthAttachment.loadAction = .load
		pass.depthAttachment.storeAction = .store

		guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
			return
		}
		encoder.setRenderPipelineState(accumulationPipelineState)
		encoder.setDepthStencilState(depthStateTransparent)

		for (index, buffer) in buffers {
			encoder.setVertexBuffer(buffer, offset: 0, index: index)
			encoder.setFragmentBuffer(buffer, offset: 0, index: index)
		}

		if let (instancesBuffer, instructions) = scene.renderInfoTransparent() {
			for (mesh, offset, count) in instructions {
				guard let mesh else { continue }
				encoder.setCullMode(mesh.cullMode)
				encoder.setVertexBuffer(mesh.vertex, offset: 0, index: 0)
				encoder.setVertexBuffer(instancesBuffer, offset: offset, index: 3)
				encoder.setFragmentBuffer(instancesBuffer, offset: offset, index: 3)

				encoder.drawIndexedPrimitives(
					type: .triangle, indexCount: mesh.count, indexType: mesh.indexType,
					indexBuffer: mesh.index, indexBufferOffset: 0, instanceCount: count
				)
			}
		}
		encoder.endEncoding()

		renderPassDescriptor.colorAttachments[0].loadAction = .load
		renderPassDescriptor.colorAttachments[0].storeAction = .store
		renderPassDescriptor.colorAttachments[1].texture = nil

		guard
			let compEncoder = commandBuffer.makeRenderCommandEncoder(
				descriptor: renderPassDescriptor)
		else { return }
		compEncoder.setRenderPipelineState(compositionPipelineState)
		compEncoder.setFragmentTexture(accum, index: 0)
		compEncoder.setFragmentTexture(reveal, index: 1)
		compEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
		compEncoder.endEncoding()
	}
}
