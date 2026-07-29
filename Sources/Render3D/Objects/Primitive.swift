import Metal
import simd

public enum Primitive {
	public struct Cube: InstanceUniformProvider {
		public init(center: Vec3, size: Float, color: Vec4) {
			self.center = center
			self.size = Vec3(size, size, size)
			self.color = color
		}

		public init(center: Vec3, size: Vec3, color: Vec4) {
			self.center = center
			self.size = size
			self.color = color
		}

		public let center: Vec3
		public let size: Vec3
		public let color: Vec4
		public var model: Matrix { Matrix.translation(center) * Matrix.scale(size) }

		public func mesh(for device: MTLDevice) -> Mesh? {
			return Mesh.cube(device)
		}
	}
	public struct Sphere: InstanceUniformProvider {
		public init(center: Vec3, radius: Float, color: Vec4) {
			self.center = center
			self.radius = radius
			self.color = color
		}

		public let center: Vec3
		public let radius: Float
		public let color: Vec4
		public var model: Matrix {
			Matrix.translation(center) * Matrix.scale(Vec3(repeating: radius))
		}

		public func mesh(for device: MTLDevice) -> Mesh? {
			return Mesh.sphere(device, vertexCnt: 100)
		}
	}
}
