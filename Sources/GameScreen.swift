import SwiftUI
import UIKit

final class GameScreenView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
        layer.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) nao implementado")
    }

    func show(_ image: CGImage) {
        layer.contents = image
    }
}

struct GameScreen: UIViewRepresentable {
    @EnvironmentObject var emulator: Emulator

    func makeUIView(context: Context) -> GameScreenView {
        let view = GameScreenView()
        emulator.screen = view
        return view
    }

    func updateUIView(_ uiView: GameScreenView, context: Context) {}
}
