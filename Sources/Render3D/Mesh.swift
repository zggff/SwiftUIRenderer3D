import Metal
@_exported import Render3DShaders

public protocol MetalIndex {
	static var metalIndexType: MTLIndexType { get }
}

extension UInt16: MetalIndex {
	public static let metalIndexType: MTLIndexType = .uint16
}

extension UInt32: MetalIndex {
	public static let metalIndexType: MTLIndexType = .uint32
}

public struct Mesh: @unchecked Sendable {
	public let vertex: MTLBuffer
	public let index: MTLBuffer
	public let count: Int
	public let indexType: MTLIndexType
	public let cullMode: MTLCullMode

	public init(
		vertex: any MTLBuffer, index: any MTLBuffer, count: Int, indexType: MTLIndexType,
		cullMode: MTLCullMode = .back
	) {
		self.vertex = vertex
		self.index = index
		self.count = count
		self.indexType = indexType
		self.cullMode = cullMode
	}

	public init?<I: MetalIndex>(
		_ device: MTLDevice, vertices: [Vertex], indices: [I], cullMode: MTLCullMode = .back
	) {
		guard !vertices.isEmpty, !indices.isEmpty else { return nil }

		let vertex = vertices.withUnsafeBytes { vPtr in
			device.makeBuffer(
				bytes: vPtr.baseAddress!,
				length: vPtr.count,
			)
		}
		let index = indices.withUnsafeBytes { iPtr in
			device.makeBuffer(
				bytes: iPtr.baseAddress!,
				length: iPtr.count,
			)
		}
		guard let vertex, let index else { return nil }

		self.init(vertex: vertex, index: index, count: indices.count, indexType: I.metalIndexType, cullMode: cullMode)
	}

	public static func cubePrimitive(_ device: MTLDevice) -> Mesh? {

		let s = Float(0.5)
		let vertices: [Vertex] = [
			Vertex(position: SIMD3<Float>(-s, -s, s)),
			Vertex(position: SIMD3<Float>(s, -s, s)),
			Vertex(position: SIMD3<Float>(s, s, s)),
			Vertex(position: SIMD3<Float>(-s, s, s)),
			Vertex(position: SIMD3<Float>(-s, -s, -s)),
			Vertex(position: SIMD3<Float>(s, -s, -s)),
			Vertex(position: SIMD3<Float>(s, s, -s)),
			Vertex(position: SIMD3<Float>(-s, s, -s)),
		]
		let indices: [UInt16] = [
			0, 1, 2, 2, 3, 0,
			1, 5, 6, 6, 2, 1,
			5, 4, 7, 7, 6, 5,
			4, 0, 3, 3, 7, 4,
			3, 2, 6, 6, 7, 3,
			4, 5, 1, 1, 0, 4,
		]
		return Mesh(device, vertices: vertices, indices: indices)
	}

	public static func cube(_ device: MTLDevice) -> Mesh? {
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
		return Mesh(device, vertices: vertices, indices: indices)
	}

	public static func sphere(_ device: MTLDevice, vertex_cnt: UInt16 = 100) -> Mesh? {
		var vertices: [Vertex] = []
		var indices: [UInt16] = []
		let radius: Float = 0.5

		for i in 0...vertex_cnt {
			let stackAngle = Float.pi / 2.0 - Float(i) * Float.pi / Float(vertex_cnt)
			let xy = radius * cosf(stackAngle)
			let y = radius * sinf(stackAngle)

			for j in 0...vertex_cnt {
				let sectorAngle = Float(j * 2) * Float.pi / Float(vertex_cnt)
				let x = xy * cosf(sectorAngle)
				let z = xy * sinf(sectorAngle)

				let pos = Vec3(x, y, z)
				let norm = normalize(pos)
				vertices.append(Vertex(position: pos, normal: norm))
			}
		}
		for i in 0..<vertex_cnt {
			var k1 = i * (vertex_cnt + 1)
			var k2 = k1 + vertex_cnt + 1

			for _ in 0..<vertex_cnt {
				if i != 0 {
					indices.append(k1)
					indices.append(k1 + 1)
					indices.append(k2)
				}
				if i != (vertex_cnt - 1) {
					indices.append(k1 + 1)
					indices.append(k2 + 1)
					indices.append(k2)
				}
				k1 += 1
				k2 += 1
			}
		}
		return Mesh(device, vertices: vertices, indices: indices)
	}
}
