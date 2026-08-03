public class MeshBuilder<I: MetalIndex>: MeshProvider {
	public var meshId = MeshID(rawValue: "\(UUID())")
	public let cachable: Bool = false

	public init() {}
	private var mesh: Mesh<I> = Mesh(vertices: [], indices: [], cullMode: .none)

	public func getMesh() throws -> Mesh<I> {
		for f in funcs {
			var context = Context(builder: self)
			try f(&context)
		}
		return mesh
	}

	public func addTriangle(_ a: Vec3, _ b: Vec3, _ c: Vec3, color: Vec4) {
		let normal = normalize(cross(b - a, c - a))
		mesh += Mesh(
			vertices: [
				Vertex(position: a, normal: normal, color: color),
				Vertex(position: b, normal: normal, color: color),
				Vertex(position: c, normal: normal, color: color),
			], indices: [0, 1, 2])
	}

	public func addQuad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3, color: Vec4) {
		let normal = normalize(cross(b - a, c - a))
		mesh += Mesh(
			vertices: [
				Vertex(position: a, normal: normal, color: color),
				Vertex(position: b, normal: normal, color: color),
				Vertex(position: c, normal: normal, color: color),
				Vertex(position: d, normal: normal, color: color),
			],
			indices: [0, 1, 2, 2, 3, 0]
		)
	}

	public var funcs: [(inout Context) throws -> Void] = []

	@discardableResult public func create(f: @escaping (inout Context) throws -> Void) -> Self {
		funcs.append(f)
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

		public func drawClosedPath(_ points: [Vec3]) {
			guard let first = points.first else { return }
			if let fillColor = fillColor, points.count >= 3 {
				for i in 1..<(points.count - 1) {
					builder.addTriangle(first, points[i], points[i + 1], color: fillColor)
				}
			}
			drawPath(points + [first])
		}

		public func drawLine(_ a: Vec3, _ b: Vec3) {
			drawPath([a, b])
		}

		public func drawPath(_ points: [Vec3]) {
			guard color != nil else { return }

			for (prev, next) in zip(points, points.dropFirst()) {
				drawOpenTube(from: prev, to: next, radius: thickness)
				drawSphere(at: prev, radius: thickness)
			}
			if let last = points.last, points.first != points.last {
				drawSphere(at: last, radius: thickness)
			}
		}

		public func drawTriangle(_ a: Vec3, _ b: Vec3, _ c: Vec3) {
			if let color {
				builder.addTriangle(a, b, c, color: color)
			}
		}

		public func drawQuad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3) {
			if let color {
				builder.addQuad(a, b, c, d, color: color)
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
				drawPath([v000, v100, v101, v001, v000, v010, v110, v111, v011, v010])
				drawPath([v100, v110])
				drawPath([v101, v111])
				drawPath([v001, v011])
			}
		}

		public func drawCube(min: Vec3, max: Vec3) {
			let size = max - min
			let center = min + size / 2
			drawCube(center: center, size: size)
		}

		public func drawMesh<J: MetalIndex>(_ mesh: Mesh<J>, transform: Matrix) {
			builder.mesh += (transform * mesh)
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
	public func getMesh() throws -> Mesh<I> { try builder.getMesh() }

}
