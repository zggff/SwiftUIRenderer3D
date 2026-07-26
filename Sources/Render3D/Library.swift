import Metal
import Render3DShaders

public struct Library {
	let library: MTLLibrary

	public enum LType {
		case builtin
		case main
		case custom(Bundle)
	}

	public enum Error: Swift.Error {
		case NoLibrary
		case NoFunction(String)
	}

	init(type: LType, for device: any MTLDevice) throws {
		switch type {
			case .builtin: library = try device.makeDefaultLibrary(bundle: .render3DShaders)
			case .main:
				guard let library = device.makeDefaultLibrary() else {
					throw Error.NoLibrary
				}
				self.library = library
			case .custom(let bundle): library = try device.makeDefaultLibrary(bundle: bundle)
		}

	}

	func makeFunction(name: String) throws -> MTLFunction {
		guard let fun = library.makeFunction(name: name) else {
			throw Error.NoFunction(name)
		}
		return fun
	}
}
