import simd

public struct Camera {
	let position: Vec3
	let up: Vec3
	let target: Vec3


	public init(position: Vec3, target: Vec3, up: Vec3) {
		self.position = position
		self.target = target
		self.up = up
	}

	public init(
		pitch: Float, yaw: Float, radius: Float, look_at: Vec3,
		origin: Vec3
	) {
		self.position =
			Vec3(radius, pitch, yaw).polar
			+ origin
		self.target = look_at
		self.up = [-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw)]
	}

	var view: Matrix {
		return Matrix.look_at(eye: position, target: target, up: up)
	}
}
