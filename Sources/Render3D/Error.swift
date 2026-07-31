import Foundation
import Metal

public enum RenderError: LocalizedError {
	case library(LibraryError)
	case pipeline(id: String, error: Error)
	case uniform(
		expected: Any.Type, from: Any.Type
	)
	case allocation(size: Int, type: Any.Type)
	case mesh
	case scene(SceneError)

	public var errorDescription: String? {
		switch self {
			case .library(let e):
				"Failed when loading library: \(e.localizedDescription)"
			case .pipeline(let id, let error):
				"RenderPipeline [\(id)] failed with \(error.localizedDescription)"
			case .uniform(let expected, let from):
				"Failed to create uniform '\(expected)' from '\(from)'."
			case .allocation(let size, let type):
				"Failed to allocate '\(size)' bytes for '\(type)'."
			case .mesh:
				"Mesh must not be empty"
			case .scene(let e):
				"Failed when constructing a scene: \(e.localizedDescription)"
		}
	}

	public enum SceneError: LocalizedError {
		case noRenderGroup(RenderGroup.ID)
		case invalidStorage
		public var errorDescription: String? {
			switch self {
				case .noRenderGroup(let id): "no render group with id: \(id)"
				case .invalidStorage: "invalid type for storage group"
			}
		}
	}

	public enum LibraryError: LocalizedError {
		case NoLibrary
		case NoFunction(String)
		public var errorDescription: String? {
			switch self {
				case .NoLibrary:
					"Failed to load the default Metal library. Make sure your .metal shader files are included in the target's build phases."
				case .NoFunction(let name):
					"Could not find a compiled Metal function named '\(name)' in the current library."
			}
		}
	}

}
