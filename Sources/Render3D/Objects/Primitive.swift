import Metal

extension MeshID {
	public static let primitiveCube: Self = "Render3D.Primitive.Cube"
	public static func primitiveSphere(vertexCnt: Int) -> Self {
		return MeshID(rawValue: "Render3D.Primitive.Sphere(\(vertexCnt))")
	}
}

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

		public var meshId: MeshID = .primitiveCube
		public func mesh(for device: MTLDevice) throws -> Mesh? {
			return try Mesh.cube(device)
		}
	}
	public struct Sphere: InstanceUniformProvider {
		public init(center: Vec3, radius: Float, color: Vec4, vertexCnt: Int = 30) {
			self.center = center
			self.radius = radius
			self.color = color
			self.vertexCnt = vertexCnt
		}

		public let center: Vec3
		public let radius: Float
		public let color: Vec4
		public let vertexCnt: Int

		public var model: Matrix {
			Matrix.translation(center) * Matrix.scale(Vec3(repeating: radius))
		}

		public var meshId: MeshID { .primitiveSphere(vertexCnt: vertexCnt) }
		public func mesh(for device: MTLDevice) throws -> Mesh? {
			return try Mesh.sphere(device, vertexCnt: UInt16(vertexCnt))
		}
	}
}
