extension Mesh {
	static func + (_ a: Mesh, _ b: Mesh) {
		let vertexCount = Self.Index(a.vertices.count)
		var vertices = a.vertices
		var indices = a.indices
		vertices.append(contentsOf: b.vertices)
		indices.append(contentsOf: b.indices.map({ $0 + vertexCount }))
	}
}

extension Vec3 {
	func perpendicularCross() -> (Vec3, Vec3)? {
		guard self.lengthSquared > Float.ulpOfOne else { return nil }
		let v: Vec3
		if abs(self.x) < Float.ulpOfOne && abs(self.y) < Float.ulpOfOne {
			v = Vec3(1, 0, 0)
		} else {
			v = Vec3(0, 0, 1)
		}
		let p1 = cross(self, v)
		let p2 = cross(self, p1)
		return (normalize(p1), normalize(p2))
	}
}

public class MeshBuilder<I: MetalIndex> {
	private var indices: [I] = []
	private var vertices: [Vertex] = []
	public var mesh: Mesh<I> {
		return Mesh<I>(vertices: vertices, indices: indices, cullMode: .none)
	}

	public func addTriangle(_ a: Vec3, _ b: Vec3, _ c: Vec3, color: Vec4) {
		let startIdx = I(vertices.count)
		let normal = normalize(cross(b - a, c - a))
		vertices.append(contentsOf: [
			Vertex(position: a, normal: normal, color: color),
			Vertex(position: b, normal: normal, color: color),
			Vertex(position: c, normal: normal, color: color),
		])
		indices.append(contentsOf: [startIdx, startIdx + 1, startIdx + 2])
	}

	public func addQuad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3, color: Vec4) {
		let startIdx = I(vertices.count)
		let normal = normalize(cross(b - a, c - a))
		vertices.append(contentsOf: [
			Vertex(position: a, normal: normal, color: color),
			Vertex(position: b, normal: normal, color: color),
			Vertex(position: c, normal: normal, color: color),
			Vertex(position: d, normal: normal, color: color),
		])
		indices.append(contentsOf: [startIdx, startIdx + 1, startIdx + 2])
		indices.append(contentsOf: [startIdx + 2, startIdx + 3, startIdx + 0])
	}

	public func create(f: (inout Context) -> Void) -> Self {
		var context = Context(builder: self)
		f(&context)
		return self
	}

	public struct Context {
		public let builder: MeshBuilder

		public var color: Vec4? = Vec4(0, 0, 0, 1)
		public var thickness: Float = 0.1
		public var fillColor: Vec4? = nil

		public func drawOpenTube(from a: Vec3, to b: Vec3, radius: Float, slices: Int = 10) {
			guard let color else { return }
			let line = b - a
			guard let (p1, p2) = line.perpendicularCross() else { return }
			for i in 0..<slices {
				let angle1 = Float.pi * 2 * Float(i) / Float(slices)
				let angle2 = Float.pi * 2 * Float(i + 1) / Float(slices)
				builder.addQuad(
					a + radius * (sin(angle1) * p1 + cos(angle1) * p2),
					a + radius * (sin(angle2) * p1 + cos(angle2) * p2),
					b + radius * (sin(angle2) * p1 + cos(angle2) * p2),
					b + radius * (sin(angle1) * p1 + cos(angle1) * p2),
					color: color)
			}
		}

		public func drawSphere(at pos: Vec3, radius: Float, slices: Int = 10, stacks: Int = 10) {
			guard let color else { return }
			let v0 = Vec3(0, radius, 0) + pos
			let v1 = Vec3(0, -radius, 0) + pos

			var mesh: [Vec3] = [v0]

			for i in 0..<(stacks - 1) {
				let phi = Float.pi * Float(i + 1) / Float(stacks)
				for j in 0..<slices {
					let theta = 2.0 * Float.pi * Float(j) / Float(slices)
					let x = sin(phi) * cos(theta)
					let y = cos(phi)
					let z = sin(phi) * sin(theta)
					mesh.append(Vec3(x, y, z) * radius + pos)
				}
			}
			mesh.append(v1)

			for i in 0..<slices {
				var i0 = i + 1
				var i1 = (i + 1) % slices + 1
				builder.addTriangle(v0, mesh[i1], mesh[i0], color: color)

				i0 = i + slices * (stacks - 2) + 1
				i1 = (i + 1) % slices + slices * (stacks - 2) + 1
				builder.addTriangle(v1, mesh[i1], mesh[i0], color: color)
			}

			for j in 0..<(stacks - 2) {
				let j0 = j * slices + 1
				let j1 = (j + 1) * slices + 1
				for i in 0..<slices {
					let i0 = j0 + i
					let i1 = j0 + (i + 1) % slices
					let i2 = j1 + (i + 1) % slices
					let i3 = j1 + i
					builder.addQuad(mesh[i0], mesh[i1], mesh[i2], mesh[i3], color: color)
				}
			}
		}

		public func drawClosedPath(points: [Vec3]) {
			guard let first = points.first else { return }
			if let fillColor = fillColor, points.count >= 3 {
				for i in 1..<(points.count - 1) {
					builder.addTriangle(first, points[i], points[i + 1], color: fillColor)
				}
			}
			drawPath(points: points + [first])
		}

		public func drawPath(points: [Vec3]) {
			guard color != nil else { return }

			for (prev, next) in zip(points, points.dropFirst()) {
				drawOpenTube(from: prev, to: next, radius: thickness)
				drawSphere(at: prev, radius: thickness)
			}
			if let last = points.last, points.first != points.last {
				drawSphere(at: last, radius: thickness)
			}
		}

		public func drawCube(center: Vec3, size: Float) {
			drawCube(center: center, size: Vec3(size, size, size))
		}

		public func drawCube(center: Vec3, size: Vec3) {
			let hx = size.x / 2.0
			let hy = size.y / 2.0
			let hz = size.z / 2.0

			let v000 = center + Vec3(-hx, -hy, -hz)
			let v100 = center + Vec3(hx, -hy, -hz)
			let v110 = center + Vec3(hx, hy, -hz)
			let v010 = center + Vec3(-hx, hy, -hz)

			let v001 = center + Vec3(-hx, -hy, hz)
			let v101 = center + Vec3(hx, -hy, hz)
			let v111 = center + Vec3(hx, hy, hz)
			let v011 = center + Vec3(-hx, hy, hz)

			if let fillColor = fillColor {
				builder.addQuad(v001, v101, v111, v011, color: fillColor)
				builder.addQuad(v100, v000, v010, v110, color: fillColor)
				builder.addQuad(v011, v111, v110, v010, color: fillColor)
				builder.addQuad(v000, v100, v101, v001, color: fillColor)
				builder.addQuad(v101, v100, v110, v111, color: fillColor)
				builder.addQuad(v000, v001, v011, v010, color: fillColor)
			}

			if thickness > 0 {
				drawPath(points: [v000, v100, v101, v001, v000, v010, v110, v111, v011, v010])
				drawPath(points: [v100, v110])
				drawPath(points: [v101, v111])
				drawPath(points: [v001, v011])
			}
		}

		public func drawCube(min: Vec3, max: Vec3) {
			let size = max - min
			let center = min + size / 2
			drawCube(center: center, size: size)
		}

	}

}

public class PrimitiveFromBuilder<I: MetalIndex>: InstancedRenderable {
	public var model: Render3D.Matrix { Matrix.translation(position) }
	public let meshId: Render3D.MeshID
	var builder: MeshBuilder = MeshBuilder<I>()

	public var color: Vec4 = Vec4(1, 1, 1, 1)
	public let cachable: Bool = false
	public let vertexColorType: Uniforms.VertexColorType = .useAsColor

	public private(set) var position: Vec3 = Vec3(0, 0, 0)

	public init(id meshId: MeshID) {
		self.meshId = meshId
	}

	public func appendMesh(f: (inout MeshBuilder<I>.Context) -> Void) -> Self {
		var context = MeshBuilder<I>.Context(builder: builder)
		f(&context)
		return self
	}
	public func position(_ position: Vec3) -> Self {
		self.position = position
		return self
	}
	public func getMesh() -> Mesh<I> { builder.mesh }

}
