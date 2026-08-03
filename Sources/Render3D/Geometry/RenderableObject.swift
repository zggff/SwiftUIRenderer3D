public struct RenderableObject {
	public typealias I = UInt16

	public struct Part: InstancedRenderable {
		public let model: Matrix
		public let color: Vec4
		public let mesh: () throws -> Mesh<I>

		public func getMesh() throws -> some MeshSource {
			try mesh()
		}
		public let meshId: MeshID
	}

	public init(transform: Matrix, color: Vec4) {
		self.transform = transform
		self.color = color
	}

	let transform: Matrix
	let color: Vec4
	public private(set) var parts: [Part] = []

	public func with<M: MeshProvider>(m: M, transform: Matrix, color: Vec4?) -> Self
	where M.MeshType == Mesh<I> {
		var new = self
		new.parts.append(
			Part(
				model: self.transform * transform, color: color ?? self.color, mesh: m.getMesh,
				meshId: m.meshId))
		return new
	}
}

public struct TextRenderer {
	static let CharWidth: Float = 1
	static let CharHeight: Float = 2
	public init(
		text: String, width: Int = 5, color: Vec3, position: Vec3 = Vec3(0, 0, 0),
		rotation: Matrix = Matrix(1)
	) {
		self.text = text
		self.width = width
		self.position = position
		self.rotation = rotation
		self.color = color
	}

	let text: String
	/// in characters
	let width: Int
	let verticalPadding: Float = 0.5
	let horizontalPadding: Float = 0.5

	let position: Vec3
	let color: Vec3
	let rotation: Matrix

	public var object: RenderableObject {
		var res = RenderableObject(
			transform: Matrix.translation(position) * rotation, color: Vec4(color, 1.0))
		// var x: Float = 0.0
		var col = 0
		var row = 0

		for c in text {
			res = res.with(
				m: c,
				transform: Matrix.translation(
					Vec3(
						Float(col) * (Self.CharWidth + horizontalPadding),
						-Float(row) * (Self.CharHeight + verticalPadding),
						0)), color: nil)

			col += 1
			if col >= width {
				row += 1
				col = 0
			}
		}
		return res
	}
}

extension Character: MeshProvider {
	public var meshId: Render3D.MeshID { MeshID(rawValue: "Character: \(self)") }

	public func getMesh() throws -> Mesh<UInt16> {
		let mesh = MeshBuilder<UInt16>()
		switch self.uppercased() {
			case "0":
				mesh.create { ctx in
					ctx.drawClosedPath([
						Vec3(0, 0, 0),
						Vec3(1, 0, 0),
						Vec3(1, 2, 0),
						Vec3(0, 2, 0),
					])
				}
			case "1":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0.2, 0, 0),
						Vec3(0.5, 0, 0),
						Vec3(0.5, 2, 0),
						Vec3(0.2, 2, 0),
					])
					ctx.drawPath([
						Vec3(0.2, 0, 0),
						Vec3(0.8, 0, 0),
					])
				}
			case "2":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 2, 0),
						Vec3(1, 2, 0),
						Vec3(1, 1, 0),
						Vec3(0, 1, 0),
						Vec3(0, 0, 0),
						Vec3(1, 0, 0),
					])
				}
			case "3":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 2, 0),
						Vec3(1, 2, 0),
						Vec3(1, 1, 0),
						Vec3(0.5, 1, 0),
						Vec3(1, 1, 0),
						Vec3(1, 0, 0),
						Vec3(0, 0, 0),
					])
				}
			case "4":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 2, 0),
						Vec3(0, 1, 0),
						Vec3(1, 1, 0),
					])
					ctx.drawPath([
						Vec3(1, 2, 0),
						Vec3(1, 0, 0),
					])
				}
			case "5":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(1, 2, 0),
						Vec3(0, 2, 0),
						Vec3(0, 1, 0),
						Vec3(1, 1, 0),
						Vec3(1, 0, 0),
						Vec3(0, 0, 0),
					])
				}
			case "6":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(1, 2, 0),
						Vec3(0, 2, 0),
						Vec3(0, 0, 0),
						Vec3(1, 0, 0),
						Vec3(1, 1, 0),
						Vec3(0, 1, 0),
					])
				}
			case "7":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 2, 0),
						Vec3(1, 2, 0),
						Vec3(0.5, 0, 0),
					])
				}
			case "8":
				mesh.create { ctx in
					ctx.drawClosedPath([
						Vec3(0, 0, 0),
						Vec3(1, 0, 0),
						Vec3(1, 1, 0),
						Vec3(0, 1, 0),
					])
					ctx.drawClosedPath([
						Vec3(0, 1, 0),
						Vec3(1, 1, 0),
						Vec3(1, 2, 0),
						Vec3(0, 2, 0),
					])
				}
			case "9":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 0, 0),
						Vec3(1, 0, 0),
						Vec3(1, 2, 0),
						Vec3(0, 2, 0),
						Vec3(0, 1, 0),
						Vec3(1, 1, 0),
					])
				}
			case "X":
				mesh.create { ctx in
					ctx.drawLine(Vec3(0, 0, 0), Vec3(1, 2, 0))
					ctx.drawLine(Vec3(0, 2, 0), Vec3(1, 0, 0))
				}
			case "Z":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 2, 0),
						Vec3(1, 2, 0),
						Vec3(0, 0, 0),
						Vec3(1, 0, 0),
					])
				}
			case "Y":
				mesh.create { ctx in
					ctx.drawPath([
						Vec3(0, 2, 0),
						Vec3(0.5, 1, 0),
						Vec3(0.5, 0, 0),
					])
					ctx.drawLine(Vec3(0.5, 1, 0), Vec3(1, 2, 0))
				}

			default:
				throw RenderError.mesh("not implemented for \(self)")
		}
		return try mesh.getMesh()
	}
}
