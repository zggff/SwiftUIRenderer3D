import Metal

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
		public var model: Matrix { Matrix.translation(center) * Matrix.scale(size) }

		public func mesh(for device: MTLDevice) -> Mesh {
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
		public var model: Matrix {
			Matrix.translation(center) * Matrix.scale(Vec3(repeating: radius))
		}

		public func mesh(for device: MTLDevice) -> Mesh {
			return Mesh.sphere(device, vertex_cnt: 100)!
		}
	}

    /// simplest cube without support for lighting and as such fewer vertices
	public struct CubePrimitive: Renderable {
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
		public var model: Matrix { Matrix.translation(center) * Matrix.scale(size) }

		public func mesh(for device: MTLDevice) -> Mesh {
			return Mesh.cubePrimitive(device)!
		}

		public var uniform: InstanceUniforms {
            debugPrint("simple uniform called")
			var uniforms = InstanceUniforms()
			uniforms.model = model
			uniforms.color = color
			uniforms.skipLight = 1
			return uniforms
		}
	}
}
