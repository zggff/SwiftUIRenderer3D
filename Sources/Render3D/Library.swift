import Metal

public struct Library {
	let library: MTLLibrary

	public enum LType {
		case builtin
		case main
		case custom(Bundle)
	}

	public init(type: LType, for device: any MTLDevice) throws {
		switch type {
			case .builtin: library = try device.makeDefaultLibrary(bundle: .render3DShaders)
			case .main:
				guard let library = device.makeDefaultLibrary() else {
					throw RenderError.library(.NoLibrary)
				}
				self.library = library
			case .custom(let bundle): library = try device.makeDefaultLibrary(bundle: bundle)
		}

	}

	public func makeFunction(name: String) throws -> MTLFunction {
		guard let fun = library.makeFunction(name: name) else {
			throw RenderError.library(.NoFunction(name))
		}
		return fun
	}
}
