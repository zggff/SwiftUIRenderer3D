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
		pitch: Float, yaw: Float, radius: Float, lookAt: Vec3,
		origin: Vec3
	) {
		self.position =
			Vec3(radius, pitch, yaw).polar
			+ origin
		self.target = lookAt
		self.up = [-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw)]
	}

	var view: Matrix {
		return Matrix.lookAt(eye: position, target: target, up: up)
	}

	public private(set) var aspect: Float = 1
	public func withAspect(_ aspect: Float) -> Camera {
		var new = self
		new.aspect = aspect
		return new
	}

	public var uniform: Uniforms.Camera {
		let projection = Matrix.projection(
			projectionFov: Float(70).degrees,
			near: 0.01,
			far: 1000,
			aspect: aspect)
		return Uniforms.Camera(
			projection: projection, view: view, position: position)

	}
}
