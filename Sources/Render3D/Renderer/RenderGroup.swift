import Metal


public final class RenderGroup {
	public struct ID: Hashable, ExpressibleByStringLiteral, RawRepresentable, Sendable {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}
		public init(stringLiteral value: String) {
			self.rawValue = value
		}
	}

	public let id: ID
	public let order: Int

	public let storage: any ObjectStorage
	public let rendererType: any MetalRenderer.Type
    public let uniformType: Uniform.Type
    public let storageType: any ObjectStorage.Type

	public init<R: MetalRenderer, S: ObjectStorage>(
		id: ID, order: Int, renderer: R.Type, storage: S.Type
	)
	where
		R.UniformType == S.UniformType
	{
		self.id = id
		self.order = order
		self.rendererType = renderer
		self.storage = storage.init()
        self.uniformType = R.UniformType.self
        self.storageType = S.self
	}
}
