import Foundation
import Metal

public enum RenderError: LocalizedError {
	case library(LibraryError)
	case pipeline(id: String, error: Error)
	case uniform(
		expected: Any.Type, from: Any.Type
	)

	public var errorDescription: String? {
		switch self {
			case .library(let e):
				return
					"Failed when loading library: \(e.localizedDescription)"
			case .pipeline(let id, let error):
				return
					"RenderPipeline [\(id)] failed with \(error.localizedDescription)"
			case .uniform(let expected, let from):
				return "Failed to create uniform '\(expected)' from '\(from)'."
		}
	}

	public enum LibraryError: LocalizedError {
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

}
