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
	var meshCache: [ObjectIdentifier: Mesh] = [:]
	public private(set) var device: any MTLDevice

	init(device: MTLDevice) {
		self.device = device
	}

	public func mesh(for obj: any Renderable) -> Mesh? {
		let objType = type(of: obj)
		guard objType.cachable else {
			return obj.mesh(for: device)
		}
		let id = ObjectIdentifier(objType)
		guard let mesh = meshCache[id] else {
			let mesh = obj.mesh(for: device)
			meshCache[id] = mesh
			return mesh
		}
		return mesh
	}
}
