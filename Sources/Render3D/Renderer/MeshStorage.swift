import Metal

public struct MeshID: Hashable, ExpressibleByStringLiteral, RawRepresentable, Sendable {
	public let rawValue: String
	public init(rawValue: String) {
		self.rawValue = rawValue
	}
	public init(stringLiteral value: String) {
		self.rawValue = value
	}
}

public class MeshCache {
	var meshCache: [MeshID: GPUMesh?] = [:]
	public private(set) var device: any MTLDevice

	init(device: MTLDevice) {
		self.device = device
	}

	public func mesh<R: MeshProvider>(for obj: R) throws -> GPUMesh? {
		let id = obj.meshId
		if let mesh = meshCache[id] { return mesh }

		let mesh = try GPUMesh(device, mesh: obj.mesh)
		if obj.cachable, let mesh {
			meshCache[id] = mesh
		}
		return mesh
	}
}
