import Metal

extension MeshID {
	public static let primitiveCube: Self = "Render3D.Primitive.Cube"
	public static func primitiveSphere(vertexCnt: Int) -> Self {
		return MeshID(rawValue: "Render3D.Primitive.Sphere(\(vertexCnt))")
	}
}

public enum Primitive {
	public struct Cube: InstancedRenderable {
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
		public func getMesh() -> some MeshSource {
			let s = Float(0.5)
			let vertices: [Vertex] = [
				Vertex(position: Vec3(-s, -s, s), normal: SIMD3<Float>(0, 0, 1)),
				Vertex(position: Vec3(s, -s, s), normal: SIMD3<Float>(0, 0, 1)),
				Vertex(position: Vec3(s, s, s), normal: SIMD3<Float>(0, 0, 1)),
				Vertex(position: Vec3(-s, s, s), normal: SIMD3<Float>(0, 0, 1)),

				Vertex(position: Vec3(s, -s, s), normal: SIMD3<Float>(1, 0, 0)),
				Vertex(position: Vec3(s, -s, -s), normal: SIMD3<Float>(1, 0, 0)),
				Vertex(position: Vec3(s, s, -s), normal: SIMD3<Float>(1, 0, 0)),
				Vertex(position: Vec3(s, s, s), normal: SIMD3<Float>(1, 0, 0)),

				Vertex(position: Vec3(s, -s, -s), normal: SIMD3<Float>(0, 0, -1)),
				Vertex(position: Vec3(-s, -s, -s), normal: SIMD3<Float>(0, 0, -1)),
				Vertex(position: Vec3(-s, s, -s), normal: SIMD3<Float>(0, 0, -1)),
				Vertex(position: Vec3(s, s, -s), normal: SIMD3<Float>(0, 0, -1)),

				Vertex(position: Vec3(-s, -s, -s), normal: SIMD3<Float>(-1, 0, 0)),
				Vertex(position: Vec3(-s, -s, s), normal: SIMD3<Float>(-1, 0, 0)),
				Vertex(position: Vec3(-s, s, s), normal: SIMD3<Float>(-1, 0, 0)),
				Vertex(position: Vec3(-s, s, -s), normal: SIMD3<Float>(-1, 0, 0)),

				Vertex(position: Vec3(-s, s, s), normal: SIMD3<Float>(0, 1, 0)),
				Vertex(position: Vec3(s, s, s), normal: SIMD3<Float>(0, 1, 0)),
				Vertex(position: Vec3(s, s, -s), normal: SIMD3<Float>(0, 1, 0)),
				Vertex(position: Vec3(-s, s, -s), normal: SIMD3<Float>(0, 1, 0)),

				Vertex(position: Vec3(-s, -s, -s), normal: SIMD3<Float>(0, -1, 0)),
				Vertex(position: Vec3(s, -s, -s), normal: SIMD3<Float>(0, -1, 0)),
				Vertex(position: Vec3(s, -s, s), normal: SIMD3<Float>(0, -1, 0)),
				Vertex(position: Vec3(-s, -s, s), normal: SIMD3<Float>(0, -1, 0)),
			]

			let indices: [UInt16] = [
				0, 1, 2, 2, 3, 0,
				4, 5, 6, 6, 7, 4,
				8, 9, 10, 10, 11, 8,
				12, 13, 14, 14, 15, 12,
				16, 17, 18, 18, 19, 16,
				20, 21, 22, 22, 23, 20,
			]
			return Mesh(vertices: vertices, indices: indices)
		}
	}
	public struct Sphere: InstancedRenderable {
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
		public func getMesh() -> some MeshSource {
			let vertexCnt: UInt16 = UInt16(vertexCnt)
			var vertices: [Vertex] = []
			var indices: [UInt16] = []
			let radius: Float = 0.5

			for i in 0...vertexCnt {
				let stackAngle = Float.pi / 2.0 - Float(i) * Float.pi / Float(vertexCnt)
				let xy = radius * cosf(stackAngle)
				let y = radius * sinf(stackAngle)

				for j in 0...vertexCnt {
					let sectorAngle = Float(j * 2) * Float.pi / Float(vertexCnt)
					let x = xy * cosf(sectorAngle)
					let z = xy * sinf(sectorAngle)

					let pos = Vec3(x, y, z)
					let norm = normalize(pos)
					vertices.append(Vertex(position: pos, normal: norm))
				}
			}
			for i in 0..<vertexCnt {
				var k1 = i * (vertexCnt + 1)
				var k2 = k1 + vertexCnt + 1

				for _ in 0..<vertexCnt {
					if i != 0 {
						indices.append(k1)
						indices.append(k1 + 1)
						indices.append(k2)
					}
					if i != (vertexCnt - 1) {
						indices.append(k1 + 1)
						indices.append(k2 + 1)
						indices.append(k2)
					}
					k1 += 1
					k2 += 1
				}
			}
			return Mesh(vertices: vertices, indices: indices)
		}
	}
}
