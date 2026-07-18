import Metal
import SharedShaderTypes

public struct Mesh {
	let vertex: MTLBuffer
	let index: MTLBuffer
	let count: Int

	init?(_ device: MTLDevice, vertices: [Vertex], indices: [UInt16]) {
		guard
			let vertex = device.makeBuffer(
				bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride),
			let index = device.makeBuffer(
				bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride)
		else {
			return nil
		}
		self.vertex = vertex
		self.index = index
		self.count = indices.count
	}

	static func cube(_ device: MTLDevice) -> Mesh? {
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

	static func sphere(_ device: MTLDevice, vertex_cnt: UInt16 = 100) -> Mesh? {
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
				vertices.append(Vertex(position: pos))
			}
		}
		for i in 0..<vertex_cnt {
			var k1 = i * (vertex_cnt + 1)
			var k2 = k1 + vertex_cnt + 1

			for _ in 0..<vertex_cnt {
				if i != 0 {
					indices.append(k1)
					indices.append(k2)
					indices.append(k1 + 1)
				}
				if i != (vertex_cnt - 1) {
					indices.append(k1 + 1)  // triangle 2
					indices.append(k2)
					indices.append(k2 + 1)
				}
				k1 += 1
				k2 += 1
			}
		}
		return Mesh(device, vertices: vertices, indices: indices)
	}
}
