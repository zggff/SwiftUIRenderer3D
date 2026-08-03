import Metal
import Render3DShaders

public protocol AnyRenderGroup {
	associatedtype Storage: ObjectStorage
	associatedtype Renderer: MetalRenderer where Renderer.UniformType == Storage.UniformType
	init()
	func removeAll()
	var renderer: Renderer.Type { get }
	var storage: Storage { get }

}

public final class RenderGroup<Renderer: MetalRenderer, Storage: ObjectStorage>: AnyRenderGroup
where Renderer.UniformType == Storage.UniformType {
	public let storage: Storage = Storage()
	public let renderer = Renderer.self

	public required init() {}

	public func removeAll() {
		self.storage.removeAll()
	}
}

public struct RenderGroupIdentity<G: AnyRenderGroup> {
	public init() {}
	public func createGroup() -> any AnyRenderGroup {
		return G()
	}
}
