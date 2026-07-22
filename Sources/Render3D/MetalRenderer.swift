import Metal
import Render3DShaders

public class MetalRenderer {
	public let device: MTLDevice!
	var commandQueue: MTLCommandQueue!
	let pipeline: MTLRenderPipelineState
	let depthState: MTLDepthStencilState

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
		pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
		pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
		pipelineDescriptor.vertexDescriptor = Vertex.defaultLayout

		self.pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

		let depthDescriptor = MTLDepthStencilDescriptor()
		depthDescriptor.depthCompareFunction = .less
		depthDescriptor.isDepthWriteEnabled = true

		self.depthState = device.makeDepthStencilState(descriptor: depthDescriptor)!
	}

	public func draw(
		scene: Scene3D,
		camera: Camera,
		viewportSize: CGSize,
		renderPassDescriptor: MTLRenderPassDescriptor,
		commandBuffer: MTLCommandBuffer
	) {
		let aspect = Float(viewportSize.width) / Float(viewportSize.height)
		let projection = Matrix.projection(
			projectionFov: Float(70).degrees,
			near: 0.1,
			far: 1000,
			aspect: aspect)
		var sceneUniforms = SceneUniforms(projection: projection, view: camera.view)

		renderPassDescriptor.depthAttachment.clearDepth = 1.0
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.depthAttachment.storeAction = .dontCare

		guard
			let renderEncoder = commandBuffer.makeRenderCommandEncoder(
				descriptor: renderPassDescriptor)
		else { return }

		renderEncoder.setCullMode(.back)
		renderEncoder.setRenderPipelineState(pipeline)
		renderEncoder.setDepthStencilState(depthState)

		renderEncoder.setVertexBytes(
			&sceneUniforms, length: MemoryLayout<SceneUniforms>.stride, index: 1)

		if let (instancesBuffer, instructions) = scene.instancesBuffer(for: device) {
			for (mesh, offset, count) in instructions {
				renderEncoder.setVertexBuffer(mesh.vertex, offset: 0, index: 0)
				renderEncoder.setVertexBuffer(instancesBuffer, offset: offset, index: 2)
				renderEncoder.drawIndexedPrimitives(
					type: .triangle, indexCount: mesh.count, indexType: .uint16,
					indexBuffer: mesh.index,
					indexBufferOffset: 0, instanceCount: count)
			}
		}

		renderEncoder.endEncoding()
	}
}
