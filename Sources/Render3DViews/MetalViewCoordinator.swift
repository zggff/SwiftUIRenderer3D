import MetalKit
import Render3D

@MainActor
public class MetalViewCoordinator: NSObject, MTKViewDelegate {
	let renderer: MetalRenderer
	var parent: MetalView

	init(_ parent: MetalView, device: MTLDevice) {
		self.parent = parent
		self.renderer = MetalRenderer(device: device)
		super.init()
	}

	public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
	}

	public func draw(in view: MTKView) {
		guard let drawable = view.currentDrawable,
			let renderPassDescriptor = view.currentRenderPassDescriptor,
			let commandBuffer = renderer.commandQueue.makeCommandBuffer()
		else { return }

		renderer.draw(
			scene: parent.scene, camera: parent.camera,
			viewportSize: view.drawableSize, renderPassDescriptor: renderPassDescriptor,
			commandBuffer: commandBuffer)

		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
}
