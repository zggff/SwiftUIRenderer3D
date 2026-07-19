import MetalKit
import SwiftUI

#if os(macOS)
	public typealias NativeView = NSView
	public typealias NativeApplication = NSApplication
	public typealias ViewRepresentable = NSViewRepresentable
	public typealias ViewRepresentableContext = NSViewRepresentableContext
	public typealias ViewControllerRepresentable = NSViewControllerRepresentable

#elseif os(iOS)
	public typealias NativeView = UIView
	public typealias NativeApplication = UIApplication
	public typealias ViewRepresentable = UIViewRepresentable
	public typealias ViewRepresentableContext = UIViewRepresentableContext
	public typealias ViewControllerRepresentable = UIViewControllerRepresentable
#endif

public struct MetalView: ViewRepresentable {
	let backgroundColor: MTLClearColor
	let camera: Camera
	@Binding var scene: Scene3D

	var onScroll: ((CGFloat) -> Void)? = nil

	private static let device: MTLDevice = {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError("No Metal device")
		}
		return device
	}()
	public func makeCoordinator() -> MetalRenderer {
		MetalRenderer(self, device: Self.device)
	}

	public init(
		backgroundColor: MTLClearColor,
		camera: Camera,
		scene: Binding<Scene3D>,
		onScroll: ((CGFloat) -> Void)? = nil
	) {
		self.backgroundColor = backgroundColor
		self.camera = camera
		self._scene = scene
		self.onScroll = onScroll
	}

	public func makeNSView(context: ViewRepresentableContext<MetalView>) -> MTKView {
		let mtkView = CustomMTKView()
		mtkView.delegate = context.coordinator
		mtkView.preferredFramesPerSecond = 60
		mtkView.enableSetNeedsDisplay = true
		mtkView.depthStencilPixelFormat = .depth32Float

		mtkView.device = Self.device
		mtkView.framebufferOnly = false
		mtkView.drawableSize = mtkView.frame.size

		mtkView.scrollHandler = onScroll
		return mtkView
	}

	private class CustomMTKView: MTKView {
		var scrollHandler: ((CGFloat) -> Void)?

		#if os(macOS)
			override func scrollWheel(with event: NSEvent) {
				if let scrollHandler = scrollHandler {
					scrollHandler(event.deltaY)
				} else {
					super.scrollWheel(with: event)
				}
			}
		#endif
	}

	public func updateNSView(_ uiView: MTKView, context: ViewRepresentableContext<MetalView>) {
		context.coordinator.parent = self

		scene.onContentChanged = { [weak uiView] in
			#if os(macOS)
				uiView?.needsDisplay = true
			#elseif os(iOS)
				uiView?.setNeedsDisplay()
			#endif
		}

		#if os(macOS)
			uiView.needsDisplay = true
		#elseif os(iOS)
			uiView.setNeedsDisplay()
		#endif
	}

	public func makeUIView(context: ViewRepresentableContext<MetalView>) -> MTKView {
		return makeNSView(context: context)
	}

	public func updateUIView(_ uiView: MTKView, context: ViewRepresentableContext<MetalView>) {
		updateNSView(uiView, context: context)
	}
}
