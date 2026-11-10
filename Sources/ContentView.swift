import SwiftUI

struct ContentView: View {
    @EnvironmentObject var emulator: Emulator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                if geo.size.height >= geo.size.width {
                    PortraitLayout()
                } else {
                    LandscapeLayout()
                }
                if !emulator.status.isEmpty {
                    Text(emulator.status)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .padding(24)
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            emulator.start()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                emulator.resume()
            } else {
                emulator.pause()
            }
        }
    }
}

struct PortraitLayout: View {
    var body: some View {
        VStack(spacing: 12) {
            GameScreen()
                .aspectRatio(3.0 / 2.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            HStack {
                ShoulderButton(title: "L", mask: GBAKey.l)
                Spacer()
                TurboButton()
                Spacer()
                ShoulderButton(title: "R", mask: GBAKey.r)
            }
            .padding(.horizontal, 20)
            HStack(alignment: .center) {
                DPad().frame(width: 160, height: 160)
                Spacer()
                ABCluster()
            }
            .padding(.horizontal, 20)
            HStack(spacing: 28) {
                PillButton(title: "SELECT", mask: GBAKey.select)
                PillButton(title: "START", mask: GBAKey.start)
            }
            .padding(.bottom, 8)
        }
    }
}

struct LandscapeLayout: View {
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 14) {
                ShoulderButton(title: "L", mask: GBAKey.l)
                DPad().frame(width: 150, height: 150)
            }
            VStack(spacing: 8) {
                GameScreen()
                    .aspectRatio(3.0 / 2.0, contentMode: .fit)
                HStack(spacing: 24) {
                    PillButton(title: "SELECT", mask: GBAKey.select)
                    TurboButton()
                    PillButton(title: "START", mask: GBAKey.start)
                }
            }
            VStack(spacing: 14) {
                ShoulderButton(title: "R", mask: GBAKey.r)
                ABCluster()
            }
        }
        .padding(.horizontal, 12)
    }
}
