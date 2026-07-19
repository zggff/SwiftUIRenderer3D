import Metal
import SharedShaderTypes
import Synchronization
import simd

private final class MeshCache: Sendable {
	static let cache = MeshCache()
	private let meshes = Mutex([ObjectIdentifier: Mesh]())

	func mesh<T: Renderable>(for type: T.Type, device: MTLDevice) -> Mesh {
		let id = ObjectIdentifier(type)

		if let mesh = meshes.withLock({ $0[id] }) {
			return mesh
		}
		let mesh = T.createMesh(for: device)
		meshes.withLock { dict in
			dict[id] = mesh
		}
		return mesh
	}
}

public protocol Renderable {
	var translation: Matrix { get }
	var color: Vec3 { get }
	static func createMesh(for device: MTLDevice) -> Mesh
}

extension Renderable {
	public func mesh(for device: MTLDevice) -> Mesh {
		return MeshCache.cache.mesh(for: Self.self, device: device)
	}
	public static func mesh(for device: MTLDevice) -> Mesh {
		return MeshCache.cache.mesh(for: Self.self, device: device)
	}
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

		public static func createMesh(for device: MTLDevice) -> Mesh {
			print("making a cube mesh")
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

		public static func createMesh(for device: MTLDevice) -> Mesh {
			print("making a sphere mesh")
			return Mesh.sphere(device, vertex_cnt: 10)!
		}
	}
}
