import simd

public typealias Matrix = float4x4
public typealias Vec3 = SIMD3<Float>
public typealias Vec4 = SIMD4<Float>

extension FloatingPoint {
	/// converts value in degrees to radians
	public var degrees: Self {
		return self * .pi / 180
	}

	/// converts value in radians to degrees
	public var radians: Self {
		return self * 180 / .pi
	}
}

extension Matrix {
	public var transposed: Matrix {
		return simd_transpose(self)
	}

	public static func projection(projectionFov fov: Float, near: Float, far: Float, aspect: Float)
		-> Matrix
	{
		let y = 1 / tan(fov * 0.5)
		let x = y / aspect
		let z = far / (far - near)
		return Matrix(
			columns: (
				Vec4(x, 0, 0, 0),
				Vec4(0, y, 0, 0),
				Vec4(0, 0, z, 1),
				Vec4(0, 0, z * -near, 0)
			)
		)
	}

	public static func translation(_ dimensions: Vec3) -> Matrix {
		return Matrix(
			Vec4(1, 0, 0, 0),
			Vec4(0, 1, 0, 0),
			Vec4(0, 0, 1, 0),
			Vec4(dimensions.x, dimensions.y, dimensions.z, 1),
		)
	}

	public static func scale(_ dimensions: Vec3) -> Matrix {
		return Matrix(diagonal: Vec4(dimensions.x, dimensions.y, dimensions.z, 1))
	}

	public static func rotation(around axis: Vec3, radians angle: Float) -> Matrix {
		let u = normalize(axis)
		let (x, y, z) = (u.x, u.y, u.z)
		let cosv = cos(angle)
		let sinv = sin(angle)

		return Matrix(
			Vec4(
				x * x * (1 - cosv) + cosv, x * y * (1 - cosv) + z * sinv,
				x * z * (1 - cosv) - y * sinv, 0),
			Vec4(
				y * x * (1 - cosv) - z * sinv, y * y * (1 - cosv) + cosv,
				y * z * (1 - cosv) + x * sinv, 0),
			Vec4(
				z * x * (1 - cosv) + y * sinv, z * y * (1 - cosv) - x * sinv,
				z * z * (1 - cosv) + cosv, 0),
			Vec4(0, 0, 0, 1),
		)
	}

	public static func look_at(eye: Vec3, target: Vec3, up: Vec3) -> Matrix {
		let forward = normalize(target - eye)
		let right = normalize(cross(up, forward))
		let trueUp = cross(forward, right)

		return Matrix(
			Vec4(right.x, trueUp.x, forward.x, 0),
			Vec4(right.y, trueUp.y, forward.y, 0),
			Vec4(right.z, trueUp.z, forward.z, 0),
			Vec4(-dot(right, eye), -dot(trueUp, eye), -dot(forward, eye), 1)
		)
	}
}

extension Vec3 {
	/// converts [radial, polar, azimuth] to [x, y, z]
	public var polar: Vec3 {
		Vec3(
			x * cos(y) * sin(z),
			x * sin(y),
			x * cos(y) * cos(z)
		)
	}

	public var length: Float {
		return simd_length(self)
	}
	public var lengthSquared: Float {
		return simd_length_squared(self)
	}

}
