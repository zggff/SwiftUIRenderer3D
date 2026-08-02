import Render3DViews
import SwiftUI

#if canImport(AppKit)
	import AppKit
	import CoreGraphics
#endif

public struct FreeCameraState {
	public init(position: Vec3 = Vec3(0, 0, 0), yaw: Float = 0, pitch: Float = 0) {
		self.position = position
		self.yaw = yaw
		self.pitch = pitch
	}
	public var position: Vec3
	public var yaw: Float = 0
	public var pitch: Float = 0

	public mutating func move(forward: Float, right: Float, up: Float) {
		let yawRad = yaw.degrees

		let forwardX = sin(yawRad)
		let forwardZ = cos(yawRad)

		let rightX = cos(yawRad)
		let rightZ = -sin(yawRad)

		let newX = position.x + (forwardX * forward) + (rightX * right)
		let newY = position.y + up
		let newZ = position.z + (forwardZ * forward) + (rightZ * right)

		self.position = Vec3(newX, newY, newZ)
	}
}

public struct FreeSceneView: View {
	public init(
		scene: Scene3D,
		cameraState: Binding<FreeCameraState>,
		moveSpeed: Float = 20.0
	) {
		self.scene = scene
		self._cameraState = cameraState
		self.moveSpeed = moveSpeed
	}

	@Binding var cameraState: FreeCameraState
	var scene: Scene3D
	var moveSpeed: Float

	@State private var activeKeys: Set<String> = []
	@State private var isShiftDown: Bool = false
	@State private var isMouseCaptured: Bool = false

	@State private var eventMonitors: [Any] = []

	let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

	private var activeCamera: Camera {
		let pitchRad = cameraState.pitch.degrees
		let yawRad = cameraState.yaw.degrees

		let forward = Vec3(
			sin(yawRad) * cos(pitchRad),
			sin(pitchRad),
			cos(yawRad) * cos(pitchRad)
		)

		let target = cameraState.position + forward
		let up = Vec3(
			-sin(pitchRad) * sin(yawRad),
			cos(pitchRad),
			-sin(pitchRad) * cos(yawRad)
		)

		return Camera(position: cameraState.position, target: target, up: up)
	}

	public var body: some View {
		#if canImport(AppKit)
			MetalView(
				backgroundColor: MTLClearColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0),
				camera: activeCamera,
				scene: scene,
				onScroll: { _ in }
			)
			.withErrorOverlay()
			.contentShape(Rectangle())
			.onTapGesture {
				captureMouse()
			}
			.onAppear {
				setupInputMonitors()
			}
			.onDisappear {
				cleanupInputMonitors()
				releaseMouse()
			}
			.onReceive(timer) { _ in
				updateMovement()
			}
		#elseif canImport(UIKit)
            Text("free camera is not implemented for uikit")
		#endif
	}

	private func updateMovement() {
		guard isMouseCaptured else { return }

		var fwdAmt: Float = 0
		var rgtAmt: Float = 0
		var upAmt: Float = 0

		let speedPerFrame = moveSpeed / 60.0

		if activeKeys.contains("w") { fwdAmt += speedPerFrame }
		if activeKeys.contains("s") { fwdAmt -= speedPerFrame }
		if activeKeys.contains("d") { rgtAmt += speedPerFrame }
		if activeKeys.contains("a") { rgtAmt -= speedPerFrame }

		if activeKeys.contains(" ") { upAmt += speedPerFrame }
		if isShiftDown { upAmt -= speedPerFrame }

		if fwdAmt != 0 || rgtAmt != 0 || upAmt != 0 {
			cameraState.move(forward: fwdAmt, right: rgtAmt, up: upAmt)
		}
	}

	#if canImport(AppKit)
		private func setupInputMonitors() {
			let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
				event in
				guard isMouseCaptured else { return event }

				if event.type == .keyDown && event.keyCode == 53 {
					releaseMouse()
					return nil
				}

				if let chars = event.charactersIgnoringModifiers?.lowercased() {
					if event.type == .keyDown {
						activeKeys.insert(chars)
					} else {
						activeKeys.remove(chars)
					}
				}
				return nil
			}

			let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
				event in
				guard isMouseCaptured else { return event }
				isShiftDown = event.modifierFlags.contains(.shift)
				return nil
			}

			let mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [
				.mouseMoved, .leftMouseDragged, .rightMouseDragged,
			]) { event in
				guard isMouseCaptured else { return event }

				let deltaX = Float(event.deltaX)
				let deltaY = Float(event.deltaY)

				let sensitivity: Float = 0.2

				cameraState.yaw += deltaX * sensitivity
				let newPitch = cameraState.pitch - deltaY * sensitivity

				cameraState.pitch = max(-89.0, min(89.0, newPitch))

				return nil
			}

			eventMonitors = [keyMonitor, flagsMonitor, mouseMonitor].compactMap { $0 }
		}

		private func cleanupInputMonitors() {
			for monitor in eventMonitors {
				NSEvent.removeMonitor(monitor)
			}
			eventMonitors.removeAll()
		}

		private func captureMouse() {
			if !isMouseCaptured {
				isMouseCaptured = true
				NSCursor.hide()
				CGAssociateMouseAndMouseCursorPosition(0)
			}
		}

		private func releaseMouse() {
			if isMouseCaptured {
				isMouseCaptured = false
				activeKeys.removeAll()
				isShiftDown = false
				NSCursor.unhide()
				CGAssociateMouseAndMouseCursorPosition(1)
			}
		}
	#endif
}
