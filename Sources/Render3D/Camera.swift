import Render3DShaders
import simd

public struct Camera {
	public let position: Vec3
	public let up: Vec3
	public let target: Vec3

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

	public func uniforms(for aspect: Float) -> CameraUniforms {
		let projection = Matrix.projection(
			projectionFov: Float(70).degrees,
			near: 1,
			far: 1000,
			aspect: aspect)
		return CameraUniforms(
			projection: projection, view: view, position: position)

	}
}
