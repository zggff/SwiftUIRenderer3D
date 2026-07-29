import Metal
import Render3DShaders

public class OpaqueRenderer: MetalRenderer {

	public let device: any MTLDevice
	let pipeline: MTLRenderPipelineState
	let depthState: MTLDepthStencilState
	let library: Library
	var instancesBuffer: MTLBuffer? = nil

	public required init(device: any MTLDevice) throws {
		self.device = device

		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		library = try Library(type: .builtin, for: device)

		pipelineDescriptor.vertexFunction = try library.makeFunction(name: "vertexMain")
		pipelineDescriptor.fragmentFunction = try library.makeFunction(name: "fragmentMain")
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
			device: device, cache: ctx.cache, buffer: &instancesBuffer, as: Uniforms.Instance.self,
			transform: Uniforms.Instance.from
		)

		guard
			let renderEncoder = ctx.commandBuffer.makeRenderCommandEncoder(
				descriptor: ctx.renderPassDescriptor)
		else { return }

		renderEncoder.setRenderPipelineState(pipeline)
		renderEncoder.setDepthStencilState(depthState)

		ctx.bindBuffer(of: Uniforms.Camera.self, to: renderEncoder, index: 1)
		ctx.bindBuffer(of: Uniforms.SceneLight.self, to: renderEncoder, index: 2)

		for i in instructions {
			guard let mesh = i.mesh else { continue }
			renderEncoder.setCullMode(mesh.cullMode)
			renderEncoder.setVertexBuffer(mesh.vertex, offset: 0, index: 0)
			renderEncoder.setVertexBuffer(instancesBuffer, offset: i.offset, index: 3)
			renderEncoder.setFragmentBuffer(instancesBuffer, offset: i.offset, index: 3)

			renderEncoder.drawIndexedPrimitives(
				type: .triangle, indexCount: mesh.count, indexType: mesh.indexType,
				indexBuffer: mesh.index,
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
			id: ID.opaque, order: 0, renderer: OpaqueRenderer.self,
			storage: GroupedObjectStorage.self)
	}
}
