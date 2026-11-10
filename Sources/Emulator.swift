import AVFoundation
import SwiftUI
import UIKit

/// Teclas do GBA, na mesma numeracao do RETRO_DEVICE_ID_JOYPAD_* usada pela ponte em C.
enum GBAKey {
    static let b: UInt32 = 1 << 0
    static let select: UInt32 = 1 << 2
    static let start: UInt32 = 1 << 3
    static let up: UInt32 = 1 << 4
    static let down: UInt32 = 1 << 5
    static let left: UInt32 = 1 << 6
    static let right: UInt32 = 1 << 7
    static let a: UInt32 = 1 << 8
    static let l: UInt32 = 1 << 10
    static let r: UInt32 = 1 << 11
    static let dpad: UInt32 = up | down | left | right
}

private final class LinkTarget: NSObject {
    weak var owner: Emulator?
    @objc func tick() {
        owner?.tick()
    }
}

final class Emulator: ObservableObject {
    @Published var status: String = ""
    @Published var turbo: Bool = false {
        didSet { gba_set_turbo(turbo ? 1 : 0) }
    }

    weak var screen: GameScreenView?

    private var keys: UInt32 = 0
    private var loaded = false
    private var started = false
    private var link: CADisplayLink?
    private let linkTarget = LinkTarget()
    private var engine: AVAudioEngine?
    private var audioOK = false
    private var tickCount = 0
    private var lastSave = Data()
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var saveURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("Jogo.sav")
    }

    // MARK: - Ciclo de vida

    func start() {
        if started { return }
        started = true
        guard let romPath = Bundle.main.path(forResource: "Game", ofType: "gba") else {
            status = "ROM não encontrada.\nO arquivo Game.gba precisa estar dentro do app."
            return
        }
        let result = gba_load(romPath)
        if result != 0 {
            status = "Não foi possível iniciar o jogo (erro \(result))."
            return
        }
        loaded = true
        loadSave()
        setupAudio()
        let target = linkTarget
        target.owner = self
        let dl = CADisplayLink(target: target, selector: #selector(LinkTarget.tick))
        if #available(iOS 15.0, *) {
            dl.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        }
        dl.add(to: .main, forMode: .common)
        link = dl
        haptic.prepare()
    }

    func pause() {
        link?.isPaused = true
        engine?.pause()
        saveIfNeeded()
    }

    func resume() {
        guard loaded else { return }
        link?.isPaused = false
        if let engine = engine, !engine.isRunning {
            try? engine.start()
        }
    }

    // MARK: - Entrada

    func press(_ mask: UInt32) {
        keys |= mask
        gba_set_keys(keys)
        haptic.impactOccurred()
    }

    func release(_ mask: UInt32) {
        keys &= ~mask
        gba_set_keys(keys)
    }

    func setDpad(_ mask: UInt32) {
        let old = keys & GBAKey.dpad
        keys = (keys & ~GBAKey.dpad) | (mask & GBAKey.dpad)
        gba_set_keys(keys)
        if mask != 0 && old == 0 {
            haptic.impactOccurred()
        }
    }

    // MARK: - Quadros

    fileprivate func tick() {
        guard loaded else { return }
        var produced = false
        if turbo {
            for _ in 0..<4 {
                gba_run_frame()
            }
            produced = true
        } else if audioOK {
            // O audio dita o ritmo: so roda quadros enquanto o buffer estiver baixo.
            var runs = 0
            while gba_audio_buffered() < 1100 && runs < 3 {
                gba_run_frame()
                runs += 1
                produced = true
            }
        } else {
            gba_run_frame()
            produced = true
        }
        if produced {
            presentFrame()
        }
        tickCount += 1
        if tickCount % 180 == 0 {
            saveIfNeeded()
        }
    }

    private func presentFrame() {
        var w: Int32 = 0
        var h: Int32 = 0
        guard let pixels = gba_frame(&w, &h), w > 0, h > 0 else { return }
        let count = Int(w) * Int(h) * 4
        let data = Data(bytes: pixels, count: count)
        guard let provider = CGDataProvider(data: data as CFData) else { return }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                                | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let image = CGImage(width: Int(w), height: Int(h),
                                  bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: Int(w) * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: info,
                                  provider: provider, decode: nil,
                                  shouldInterpolate: false, intent: .defaultIntent) else { return }
        screen?.show(image)
    }

    // MARK: - Audio

    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            NSLog("Audio: sessao falhou: \(error)")
        }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 32768, channels: 2, interleaved: false) else { return }
        let engine = AVAudioEngine()
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            _ = gba_audio_pull(left, right, Int32(frameCount))
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            self.engine = engine
            audioOK = true
        } catch {
            NSLog("Audio: engine falhou: \(error)")
        }
    }

    // MARK: - Save

    private func loadSave() {
        guard let saved = try? Data(contentsOf: saveURL), !saved.isEmpty,
              let ptr = gba_save_data() else { return }
        let size = gba_save_size()
        let n = min(saved.count, size)
        saved.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                memcpy(ptr, base, n)
            }
        }
        lastSave = saved
    }

    func saveIfNeeded() {
        guard loaded, let ptr = gba_save_data() else { return }
        let size = gba_save_size()
        guard size > 0 else { return }
        let current = Data(bytes: ptr, count: size)
        if current != lastSave {
            do {
                try current.write(to: saveURL, options: .atomic)
                lastSave = current
            } catch {
                NSLog("Save falhou: \(error)")
            }
        }
    }
}
