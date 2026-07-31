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

public struct Mesh {
	public enum IndexData {
		case uint16([UInt16])
		case uint32([UInt32])
	}

	public let vertices: [Vertex]
	public let indices: IndexData
	public let cullMode: MTLCullMode

	public init(
		vertices: [Vertex],
		indices: IndexData,
		cullMode: MTLCullMode = .none,
	) {
		self.vertices = vertices
		self.indices = indices
		self.cullMode = cullMode
	}
}

public struct GPUMesh {
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

	public init?(_ device: MTLDevice, mesh: Mesh) throws {
		switch mesh.indices {
			case .uint16(let indices):
				try self.init(
					device, vertices: mesh.vertices, indices: indices)
			case .uint32(let indices):
				try self.init(
					device, vertices: mesh.vertices, indices: indices)
		}
	}

	public init?<I: MetalIndex>(
		_ device: MTLDevice, vertices: [Vertex], indices: [I],
		cullMode: MTLCullMode = .back,
	) throws {
		guard !vertices.isEmpty, !indices.isEmpty else { return nil }
		guard
			let vertex = vertices.withUnsafeBytes({ vPtr in
				device.makeBuffer(
					bytes: vPtr.baseAddress!,
					length: vPtr.count,
				)
			})
		else {
			throw RenderError.allocation(
				size: vertices.count * MemoryLayout<Vertex>.stride,
				type: Vertex.self
			)
		}
		guard
			let index = indices.withUnsafeBytes({ iPtr in
				device.makeBuffer(
					bytes: iPtr.baseAddress!,
					length: iPtr.count,
				)
			})
		else {
			throw RenderError.allocation(
				size: indices.count * MemoryLayout<I>.stride,
				type: I.self
			)
		}
		self.init(
			vertex: vertex, index: index, count: indices.count, indexType: I.metalIndexType,
			cullMode: cullMode)
	}
}
