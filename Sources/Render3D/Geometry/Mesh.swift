import Metal
@_exported import Render3DShaders

public protocol MetalIndex: UnsignedInteger {
	static var metalIndexType: MTLIndexType { get }
}

extension UInt16: MetalIndex {
	public static let metalIndexType: MTLIndexType = .uint16
}

extension UInt32: MetalIndex {
	public static let metalIndexType: MTLIndexType = .uint32
}

public protocol MeshSource {
	associatedtype Index: MetalIndex
	var vertices: [Vertex] { get }
	var indices: [Index] { get }
	var cullMode: MTLCullMode { get }
}

public struct Mesh<Index: MetalIndex>: MeshSource {
	public var vertices: [Vertex]
	public var indices: [Index]
	public let cullMode: MTLCullMode

	public init(
		vertices: [Vertex],
		indices: [Index],
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

	public init?(_ device: MTLDevice, mesh: some MeshSource) throws {
		try self.init(
			device, vertices: mesh.vertices, indices: mesh.indices, cullMode: mesh.cullMode)
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

extension Mesh {
	static func + <I: MetalIndex, J: MetalIndex>(_ a: Mesh<I>, _ b: Mesh<J>) -> any MeshSource {
		let totalCount = a.vertices.count + b.vertices.count
		if totalCount > UInt16.max {
			return combineMeshes(a, b, target: UInt32.self)
		}
		return combineMeshes(a, b, target: UInt16.self)
	}

	private static func combineMeshes<I: MetalIndex, J: MetalIndex, T: MetalIndex>(
		_ a: Mesh<I>, _ b: Mesh<J>, target: T.Type
	) -> Mesh<T> {
		let count = T(a.vertices.count)
		let vertices = a.vertices + b.vertices
		let indices = a.indices.map({ T($0) }) + b.indices.map({ T($0) + count })
		return Mesh<T>(vertices: vertices, indices: indices, cullMode: a.cullMode)
	}

	static func += <J: MetalIndex>(_ a: inout Mesh, _ b: Mesh<J>) {
		let vertexCount = Self.Index(a.vertices.count)
		a.vertices.append(contentsOf: b.vertices)
		a.indices.append(contentsOf: b.indices.map({ Self.Index($0) + vertexCount }))
	}

	static func += (_ a: inout Mesh, _ b: Mesh) {
		let vertexCount = Self.Index(a.vertices.count)
		a.vertices.append(contentsOf: b.vertices)
		a.indices.append(contentsOf: b.indices.map({ $0 + vertexCount }))
	}

	static func * (_ mat: Matrix, _ mesh: Mesh) -> Mesh {
		let inv = mat.inverse.transposed
		let vertices = mesh.vertices.map({ v in
			let newPos = mat * Vec4(v.position, 1.0)
			let newNormal = inv * Vec4(v.normal, 0.0)

			return Vertex(
				position: newPos.xyz, normal: normalize(newNormal.xyz), colorUV: v.colorUV)
		})
		return Mesh(vertices: vertices, indices: mesh.indices, cullMode: mesh.cullMode)
	}
}
