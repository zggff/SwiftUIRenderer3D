import SwiftUI

extension MetalView {
	public func withErrorOverlay() -> some View {
		MetalViewErrorOverlayWrapper(baseView: self)
	}
}

public struct MetalViewErrorOverlayWrapper: View {
	private var baseView: MetalView
	@State private var currentError: Error?

	public init(baseView: MetalView) {
		self.baseView = baseView
	}

	public var body: some View {
		ZStack {
			modifiedMetalView
			if let error = currentError {
				errorOverlay(for: error)
			}
		}
	}

	private var modifiedMetalView: MetalView {
		var view = baseView
		let originalOnError = view.onError

		view.onError = { error in
			DispatchQueue.main.async {
				self.currentError = error
			}
			originalOnError?(error)
		}
		return view
	}

	private func errorOverlay(for error: Error) -> some View {
		VStack(spacing: 8) {
			HStack {
				Image(systemName: "exclamationmark.triangle.fill")
				Text("Metal Rendering Error")
					.font(.headline)
			}
			.foregroundColor(.yellow)

			Text(error.localizedDescription)
				.font(.subheadline)
				.multilineTextAlignment(.center)
				.foregroundColor(.white)

			Button("Dismiss") {
				currentError = nil
			}
			.padding(.top, 4)
			.buttonStyle(.bordered)
			.tint(.white)
		}
		.padding()
		.background(Color.black.opacity(0.85))
	}
}
