import MetalKit
import SharedShaderTypes

@MainActor
public class MetalRenderer: NSObject, MTKViewDelegate {
	var parent: MetalView
	var device: MTLDevice!
	var commandQueue: MTLCommandQueue!
	let pipeline: MTLRenderPipelineState
	let depthState: MTLDepthStencilState

	var projection: Matrix = Matrix(1)

	init(_ parent: MetalView, device: MTLDevice) {
		self.parent = parent
		self.device = device
		self.commandQueue = device.makeCommandQueue()

		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		let library: MTLLibrary
		do {
			library = try device.makeDefaultLibrary(bundle: .module)
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
		super.init()
	}

	public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let aspect = Float(view.bounds.width) / Float(view.bounds.height)
		projection = Matrix.projection(
			projectionFov: Float(70).degrees,
			near: 0.1,
			far: 1000,
			aspect: aspect)
	}

	public func draw(in view: MTKView) {
		var sceneUniforms = SceneUniforms(projection: projection, view: parent.camera.view)

		guard let drawable = view.currentDrawable else { return }

		let commandBuffer = commandQueue.makeCommandBuffer()!
		let renderPassDescriptor = view.currentRenderPassDescriptor!

		renderPassDescriptor.colorAttachments[0].clearColor = self.parent.backgroundColor
		renderPassDescriptor.colorAttachments[0].loadAction = .clear
		renderPassDescriptor.colorAttachments[0].storeAction = .store

		renderPassDescriptor.depthAttachment.clearDepth = 1.0
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.depthAttachment.storeAction = .dontCare

		let renderEncoder = commandBuffer.makeRenderCommandEncoder(
			descriptor: renderPassDescriptor)!
		renderEncoder.setCullMode(.back)
		renderEncoder.setRenderPipelineState(pipeline)
		renderEncoder.setDepthStencilState(depthState)

		renderEncoder.setVertexBytes(
			&sceneUniforms, length: MemoryLayout<SceneUniforms>.stride, index: 1)

		if let (instancesBuffer, instructions) = parent.scene.instancesBuffer(for: device) {
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

		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
}
