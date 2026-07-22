import SwiftUI

public struct OrbitingCameraState {
	public init(yaw: Float = 0, pitch: Float = 0, distance: Float = 100) {
		self.yaw = yaw
		self.pitch = pitch
		self.distance = distance
	}
	public var yaw: Float = 0
	public var pitch: Float = 0
	public var distance: Float = 100
}

public struct OrbitingSceneView: View {
	public init(
		scene: Scene3D,
		cameraState: Binding<OrbitingCameraState>,
		cameraCenter: Vec3 = Vec3(0, 0, 0)
	) {
		self.scene = scene
		self._cameraState = cameraState
		self.cameraCenter = cameraCenter
	}

	@Binding var cameraState: OrbitingCameraState
	var scene: Scene3D
	let minDistance: Float = 4.0
	let cameraCenter: Vec3

	public var body: some View {
		MetalView(
			backgroundColor: MTLClearColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0),
			camera: Camera(
				pitch: cameraState.pitch.degrees, yaw: cameraState.yaw.degrees,
				radius: cameraState.distance,
				look_at: cameraCenter,
				origin: cameraCenter),
			scene: scene,
			onScroll: { deltaY in
				cameraState.distance = max(minDistance, cameraState.distance - Float(deltaY))
			}
		).gesture(
			DragGesture()
				.onChanged { value in
					self.cameraState.yaw += Float(value.velocity.width) / 100
					self.cameraState.pitch += Float(value.velocity.height) / 100
				}.simultaneously(
					with: MagnifyGesture()
						.onChanged { value in
							let delta = Float(value.velocity)
							cameraState.distance = max(
								minDistance, cameraState.distance - delta * 5.0)
						})
		)
	}
}
