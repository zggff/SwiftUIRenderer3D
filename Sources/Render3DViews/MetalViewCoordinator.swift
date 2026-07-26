import MetalKit
import Render3D

@MainActor
public class MetalViewCoordinator: NSObject, MTKViewDelegate {
	let renderer: Renderer
	var parent: MetalView
	var commandQueue: MTLCommandQueue!
	var needsSizeUpdate = false

	init(_ parent: MetalView, device: MTLDevice) {
		self.parent = parent
		self.commandQueue = device.makeCommandQueue()
		self.renderer = Renderer(device: device)

		super.init()
	}

	public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		needsSizeUpdate = true
	}

	public func draw(in view: MTKView) {
		guard let drawable = view.currentDrawable,
			let renderPassDescriptor = view.currentRenderPassDescriptor,
			let commandBuffer = commandQueue.makeCommandBuffer()
		else { return }

		if needsSizeUpdate {
            needsSizeUpdate = false
			renderer.update(drawableSize: view.drawableSize)
		}

		try? renderer.draw(
			scene: parent.scene, camera: parent.camera,
			renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer)

		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
}
