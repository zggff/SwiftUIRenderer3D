import Metal

public final class RenderGroup {
	public let id: String
	public let order: Int

	public let storage: any ObjectStorage
	public let rendererType: MetalRenderer.Type

	public init<R: MetalRenderer, S: ObjectStorage>(
		id: String, order: Int, renderer: R.Type, storage: S.Type
	) {
		self.id = id
		self.order = order
		self.rendererType = renderer
		self.storage = storage.init()
	}
}
