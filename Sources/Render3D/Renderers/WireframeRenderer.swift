import Metal
import Render3DShaders

public enum RenderMode {
	public protocol Primitive {
		static var primitiveType: MTLPrimitiveType { get }
	}

	public struct Line: Primitive {
		public static var primitiveType: MTLPrimitiveType { .line }
	}

	public struct Triangle: Primitive {
		public static var primitiveType: MTLPrimitiveType { .triangle }
	}
}

public class NoLightRenderer<T: RenderMode.Primitive>: MetalRenderer {

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
		pipelineDescriptor.fragmentFunction = try library.makeFunction(
			name: "fragmentWireframeMain")
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
			device: device, cache: ctx.cache, buffer: &instancesBuffer[ctx.frameIndex],
			as: Uniforms.Instance.self,
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
			renderEncoder.setCullMode(i.mesh.cullMode)
			renderEncoder.setVertexBuffer(i.mesh.vertex, offset: 0, index: 0)
			renderEncoder.setVertexBuffer(
				instancesBuffer[ctx.frameIndex], offset: i.offset, index: 3)
			renderEncoder.setFragmentBuffer(
				instancesBuffer[ctx.frameIndex], offset: i.offset, index: 3)

			renderEncoder.drawIndexedPrimitives(
				type: T.primitiveType, indexCount: i.mesh.count, indexType: i.mesh.indexType,
				indexBuffer: i.mesh.index,
				indexBufferOffset: 0, instanceCount: i.count)
		}

		renderEncoder.endEncoding()
	}
}

extension RenderGroup.ID {
	public static let wireframe: RenderGroup.ID = "builtin.wireframe"
	public static let noLight: RenderGroup.ID = "builtin.noLight"
}

extension RenderGroup {
	public static var wireframe: RenderGroup {
		RenderGroup(
			id: ID.wireframe, order: 1, renderer: NoLightRenderer<RenderMode.Line>.self,
			storage: GroupedObjectStorage.self)
	}
	public static var noLight: RenderGroup {
		RenderGroup(
			id: ID.noLight, order: 2, renderer: NoLightRenderer<RenderMode.Triangle>.self,
			storage: GroupedObjectStorage.self)
	}

}
