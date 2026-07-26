import Metal
import Render3DShaders

public struct Library {
	let library: MTLLibrary

	public enum LType {
		case builtin
		case main
		case custom(Bundle)
	}

	public enum Error: Swift.Error, LocalizedError {
		case NoLibrary
		case NoFunction(String)

		public var errorDescription: String? {
			switch self {
				case .NoLibrary:
					return
						"Failed to load the default Metal library. Make sure your .metal shader files are included in the target's build phases."
				case .NoFunction(let name):
					return
						"Could not find a compiled Metal function named '\(name)' in the current library."
			}
		}
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
