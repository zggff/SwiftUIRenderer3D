import Metal
import Render3DShaders

public class OpaqueRenderer: MetalRenderer<Uniforms.Instance> {

	public let device: any MTLDevice
	let pipeline: MTLRenderPipelineState
	let depthState: MTLDepthStencilState
	let library: Library
	var instancesBuffer: RingBuffer

	public required init(device: any MTLDevice, frameCount: Int) throws {
		self.device = device
		self.instancesBuffer = RingBuffer(frameCount: frameCount)

		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		library = try Library(type: .builtin, for: device)

		pipelineDescriptor.vertexFunction = try library.makeFunction(name: "vertexMain")
		pipelineDescriptor.fragmentFunction = try library.makeFunction(name: "fragmentLightMain")
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

		self.pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

		let depthDescriptor = MTLDepthStencilDescriptor()
		depthDescriptor.depthCompareFunction = .less
		depthDescriptor.isDepthWriteEnabled = true
		self.depthState = device.makeDepthStencilState(descriptor: depthDescriptor)!
	}

	public func update(drawableSize size: CGSize) {}

	public func draw(context ctx: RenderContext, group: RenderGroup) throws {
		let instructions = try group.storage.renderInfo(
			device: device, cache: ctx.cache, buffer: &instancesBuffer[ctx.frameIndex])

		guard
			let renderEncoder = ctx.commandBuffer.makeRenderCommandEncoder(
				descriptor: ctx.renderPassDescriptor)
		else { return }

		renderEncoder.setRenderPipelineState(pipeline)
		renderEncoder.setDepthStencilState(depthState)

		ctx.bindBuffer(of: Uniforms.Camera.self, to: renderEncoder, index: 1)
		ctx.bindBuffer(of: Uniforms.SceneLight.self, to: renderEncoder, index: 2)

		for i in instructions {
			renderEncoder.setCullMode(i.mesh.cullMode)
			renderEncoder.setVertexBuffer(i.mesh.vertex, offset: 0, index: 0)
			renderEncoder.setVertexBuffer(
				instancesBuffer[ctx.frameIndex], offset: i.offset, index: 3)
			renderEncoder.setFragmentBuffer(
				instancesBuffer[ctx.frameIndex], offset: i.offset, index: 3)

			renderEncoder.drawIndexedPrimitives(
				type: .triangle, indexCount: i.mesh.count, indexType: i.mesh.indexType,
				indexBuffer: i.mesh.index,
				indexBufferOffset: 0, instanceCount: i.count)
		}

		renderEncoder.endEncoding()
	}
}

extension RenderGroup.ID {
	public static let opaque: RenderGroup.ID = "builtin.opaque"
}

extension RenderGroup {
	public static var opaque: RenderGroup {
		RenderGroup(
			id: .opaque, order: 0, renderer: OpaqueRenderer.self,
			storage: GroupedObjectStorage<Uniforms.Instance>.self)
	}
}
