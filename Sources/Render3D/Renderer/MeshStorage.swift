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
	var meshCache: [MeshID: Mesh?] = [:]
	public private(set) var device: any MTLDevice

	init(device: MTLDevice) {
		self.device = device
	}

	public func mesh(for obj: any Renderable) throws -> Mesh? {
		let id = obj.meshId
		if let mesh = meshCache[id] { return mesh }

		let mesh = try obj.mesh(for: device)
		if obj.cachable, let mesh {
			meshCache[id] = mesh
		}
		return mesh
	}
}
