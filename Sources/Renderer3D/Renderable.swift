import Metal
import SharedShaderTypes
import Synchronization
import simd

public protocol Renderable {
	var translation: Matrix { get }
	var color: Vec3 { get }
	static func mesh(for device: MTLDevice) -> Mesh
}

extension Renderable {
	public var uniform: InstanceUniforms {
		InstanceUniforms(
			translation: self.translation, color: self.color)
	}
}

public enum Primitive {
	public struct Cube: Renderable {
		public init(center: Vec3, size: Float, color: Vec3) {
			self.center = center
			self.size = Vec3(size, size, size)
			self.color = color
		}

		public init(center: Vec3, size: Vec3, color: Vec3) {
			self.center = center
			self.size = size
			self.color = color
		}

		public let center: Vec3
		public let size: Vec3
		public let color: Vec3
		public var translation: Matrix { Matrix.translation(center) * Matrix.scale(size) }

		public static func mesh(for device: MTLDevice) -> Mesh {
			debugPrint("making a cube mesh")
			return Mesh.cube(device)!
		}
	}
	public struct Sphere: Renderable {
		public init(center: Vec3, radius: Float, color: Vec3) {
			self.center = center
			self.radius = radius
			self.color = color
		}

		public let center: Vec3
		public let radius: Float
		public let color: Vec3
		public var translation: Matrix {
			Matrix.translation(center) * Matrix.scale(Vec3(repeating: radius))
		}

		public static func mesh(for device: MTLDevice) -> Mesh {
			debugPrint("making a sphere mesh")
			return Mesh.sphere(device, vertex_cnt: 10)!
		}
	}
}
