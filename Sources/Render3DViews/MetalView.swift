import MetalKit
@_exported import Render3D
import SwiftUI

#if canImport(AppKit)
	public typealias NativeView = NSView
	public typealias NativeApplication = NSApplication
	public typealias ViewRepresentable = NSViewRepresentable
	public typealias ViewRepresentableContext = NSViewRepresentableContext
	public typealias ViewControllerRepresentable = NSViewControllerRepresentable

#elseif canImport(UIKit)
	public typealias NativeView = UIView
	public typealias NativeApplication = UIApplication
	public typealias ViewRepresentable = UIViewRepresentable
	public typealias ViewRepresentableContext = UIViewRepresentableContext
	public typealias ViewControllerRepresentable = UIViewControllerRepresentable
#endif

public struct MetalView: ViewRepresentable {
	let backgroundColor: MTLClearColor
	let camera: Camera
	var scene: Scene3D

	var onScroll: ((CGFloat) -> Void)?
	var onError: ((Error?) -> Void)?

	private static let device: MTLDevice = {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError("No Metal device")
		}
		return device
	}()
	public func makeCoordinator() -> MetalViewCoordinator {
		MetalViewCoordinator(self, device: Self.device)
	}

	public init(
		backgroundColor: MTLClearColor,
		camera: Camera,
		scene: Scene3D,
		onScroll: ((CGFloat) -> Void)? = nil,
        onError: ((Error?) -> Void)? = nil
	) {
		self.backgroundColor = backgroundColor
		self.camera = camera
		self.scene = scene
		self.onScroll = onScroll
		self.onError = onError
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
		mtkView.clearColor = backgroundColor

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

	@inline(always)
	static func updateView(_ view: MTKView?) {
		#if canImport(AppKit)
			view?.needsDisplay = true
		#elseif canImport(UIKit)
			view?.setNeedsDisplay()
		#endif
	}

	public func updateNSView(_ uiView: MTKView, context: ViewRepresentableContext<MetalView>) {
		uiView.clearColor = backgroundColor
		context.coordinator.parent = self

		scene.onFinishDeclaration = { [weak uiView] in
			Self.updateView(uiView)
		}

		Self.updateView(uiView)

	}

	public func makeUIView(context: ViewRepresentableContext<MetalView>) -> MTKView {
		return makeNSView(context: context)
	}

	public func updateUIView(_ uiView: MTKView, context: ViewRepresentableContext<MetalView>) {
		updateNSView(uiView, context: context)
	}
}
