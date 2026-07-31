import Metal

public protocol MetalRenderer<UniformType>: AnyObject {
    associatedtype UniformType: Uniform
	init(device: any MTLDevice, frameCount: Int) throws
	func update(drawableSize size: CGSize)
	func draw(context: RenderContext, group: RenderGroup) throws
}

public struct RenderContext {
	public let scene: Scene3D
	public let camera: Camera
	public let renderPassDescriptor: MTLRenderPassDescriptor
	public let commandBuffer: MTLCommandBuffer
	public let depthTexture: MTLTexture

	public let cache: MeshCache
	public let buffers: [ObjectIdentifier: MTLBuffer]
	public let frameIndex: Int

	public func bindFragmentBuffer<T: Uniform>(
		of type: T.Type, to encoder: MTLRenderCommandEncoder, index: Int,
	) {
		encoder.setFragmentBuffer(buffers[ObjectIdentifier(type)], offset: 0, index: index)
	}
	public func bindVertexBuffer<T: Uniform>(
		of type: T.Type, to encoder: MTLRenderCommandEncoder, index: Int,
	) {
		encoder.setVertexBuffer(buffers[ObjectIdentifier(type)], offset: 0, index: index)
	}

	public func bindBuffer<T: Uniform>(
		of type: T.Type, to encoder: MTLRenderCommandEncoder, index: Int,
	) {
		bindFragmentBuffer(of: type, to: encoder, index: index)
		bindVertexBuffer(of: type, to: encoder, index: index)
	}
}

public struct RingBuffer {
	var buffers: [MTLBuffer?]
	public init(frameCount: Int) {
		buffers = Array(repeating: nil, count: frameCount)
	}
	public subscript(_ index: Int) -> MTLBuffer? {
		get { buffers[index] }
		set { buffers[index] = newValue }
	}
}

public class Renderer {
	let device: any MTLDevice
	var depthTexture: MTLTexture?
	var meshCache: MeshCache

	var renderers: [RenderGroup.ID: (any MetalRenderer)] = [:]
	var size: CGSize = CGSize(width: 1, height: 1)

	var ringBuffers: [[ObjectIdentifier: MTLBuffer]]
	let frameCount: Int
	let semaphore: DispatchSemaphore
	var frameIndex: Int = 0

	public init(device: any MTLDevice, frameCount: Int = 3) {
		self.device = device
		self.meshCache = MeshCache(device: device)

		self.frameCount = frameCount
		self.ringBuffers = Array(repeating: [:], count: frameCount)
		self.semaphore = DispatchSemaphore(value: frameCount)
	}

	public func prepare(for scene: Scene3D) throws {
		for g in scene.renderGroups {
			if renderers[g.id] == nil {
				do {
					renderers[g.id] = try g.rendererType.init(
						device: device, frameCount: frameCount)
				} catch {
					throw RenderError.pipeline(id: g.id.rawValue, error: error)
				}
			}
		}

	}

	public func prepared(for scene: Scene3D) -> Bool {
		return scene.renderGroups.allSatisfy({ g in renderers.keys.contains(g.id) })
	}

	public func update(drawableSize size: CGSize) {
		updateDepthTexture(size: size)
		self.size = size
		for renderer in renderers.values {
			renderer.update(drawableSize: size)
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
		_ = semaphore.wait(timeout: .distantFuture)
		let sem = semaphore

		commandBuffer.addCompletedHandler({ _ in sem.signal() })

		try prepare(for: scene)
		update(drawableSize: size)
		guard let depthTexture else { return }

		let camera = camera.withAspect(Float(size.width) / Float(size.height))

		var buffers = ringBuffers[frameIndex]
		camera.uniform.allocateAndWrite(
			for: device, buffer: &buffers[ObjectIdentifier(Uniforms.Camera.self)])
		for (k, v) in scene.uniforms {
			v.allocateAndWrite(for: device, buffer: &buffers[k])
		}

		renderPassDescriptor.depthAttachment.texture = depthTexture
		renderPassDescriptor.depthAttachment.clearDepth = 1.0
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.depthAttachment.storeAction = .store
		renderPassDescriptor.depthAttachment.loadAction = .clear
		renderPassDescriptor.colorAttachments[0].loadAction = .clear

		let context = RenderContext(
			scene: scene, camera: camera,
			renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer, depthTexture: depthTexture,
			cache: meshCache,
			buffers: buffers,
			frameIndex: frameIndex
		)

		for g in scene.renderGroups.sorted(by: { a, b in a.order < b.order }) {
			guard let renderer = renderers[g.id] else { continue }
			try renderer.draw(context: context, group: g)
			renderPassDescriptor.colorAttachments[0].loadAction = .load
			renderPassDescriptor.depthAttachment.loadAction = .load
		}

		frameIndex = (frameIndex + 1) % frameCount
	}
}
