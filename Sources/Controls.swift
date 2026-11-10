import SwiftUI

/// Botao que fica apertado enquanto o dedo esta em cima.
struct HoldButton<Label: View>: View {
    @EnvironmentObject var emulator: Emulator
    let mask: UInt32
    let label: () -> Label
    @State private var pressed = false

    var body: some View {
        label()
            .opacity(pressed ? 0.55 : 1.0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            emulator.press(mask)
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        emulator.release(mask)
                    }
            )
    }
}

struct ShoulderButton: View {
    let title: String
    let mask: UInt32

    var body: some View {
        HoldButton(mask: mask) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 84, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.18)))
        }
    }
}

struct PillButton: View {
    let title: String
    let mask: UInt32

    var body: some View {
        HoldButton(mask: mask) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 84, height: 30)
                .background(Capsule().fill(Color.white.opacity(0.18)))
        }
    }
}

private func roundLabel(_ text: String) -> some View {
    Text(text)
        .font(.title2.bold())
        .foregroundColor(.white)
        .frame(width: 68, height: 68)
        .background(Circle().fill(Color.white.opacity(0.2)))
}

struct ABCluster: View {
    var body: some View {
        ZStack {
            HoldButton(mask: GBAKey.b) { roundLabel("B") }
                .offset(x: -38, y: 26)
            HoldButton(mask: GBAKey.a) { roundLabel("A") }
                .offset(x: 38, y: -26)
        }
        .frame(width: 170, height: 140)
    }
}

struct TurboButton: View {
    @EnvironmentObject var emulator: Emulator

    var body: some View {
        Button(action: { emulator.turbo.toggle() }) {
            Text(emulator.turbo ? "▶▶ LIGADO" : "▶▶ ACELERAR")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 110, height: 30)
                .background(Capsule().fill(emulator.turbo ? Color.green.opacity(0.6) : Color.white.opacity(0.18)))
        }
    }
}

struct DPad: View {
    @EnvironmentObject var emulator: Emulator

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Color.white.opacity(0.14))
                Image(systemName: "chevron.up").offset(y: -side * 0.32)
                Image(systemName: "chevron.down").offset(y: side * 0.32)
                Image(systemName: "chevron.left").offset(x: -side * 0.32)
                Image(systemName: "chevron.right").offset(x: side * 0.32)
            }
            .foregroundColor(Color.white.opacity(0.8))
            .frame(width: side, height: side)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        emulator.setDpad(DPad.mask(for: value.location, side: side))
                    }
                    .onEnded { _ in
                        emulator.setDpad(0)
                    }
            )
        }
    }

    static func mask(for point: CGPoint, side: CGFloat) -> UInt32 {
        let dx = point.x - side / 2
        let dy = point.y - side / 2
        let ax = abs(dx)
        let ay = abs(dy)
        let dead = side * 0.10
        var mask: UInt32 = 0
        if ax > dead || ay > dead {
            if ax > ay * 0.5 && ax > dead * 0.6 {
                mask |= dx < 0 ? GBAKey.left : GBAKey.right
            }
            if ay > ax * 0.5 && ay > dead * 0.6 {
                mask |= dy < 0 ? GBAKey.up : GBAKey.down
            }
        }
        return mask
    }
}
