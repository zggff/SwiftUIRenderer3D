import Metal

public final class RenderGroup {
	public let id: String
	public let order: Int

	let storage = ObjectStorage()
	let rendererType: MetalRenderer.Type
	var renderer: (any MetalRenderer)?

	init<R: MetalRenderer>(id: String, order: Int, renderer: R.Type) {
		self.id = id
		self.order = order
		self.rendererType = renderer
	}
}
