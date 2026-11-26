import AVFoundation
import LocalAuthentication
import Observation
import PTPCore

/// The iPhone siren: a full-screen alarm and a loud two-tone sound while the app is alive (ADR-0013).
/// It starts only on a live, fresh Alarm from the watch, and stops on the owner's Face ID or passcode,
/// or when the watch reports a newer state that isn't Alarm.
@MainActor
@Observable
final class Siren {
    private(set) var isSounding = false
    private let engine = AVAudioEngine()
    private var tone: AVAudioSourceNode?

    func receive(_ report: WatchReport, live: Bool) {
        if live, report.soundsSiren(at: .now) {
            start()
        } else if report.state != .alarm {
            stop()
        }
    }

    func start() {
        guard !isSounding else { return }
        isSounding = true
        let session = AVAudioSession.sharedInstance()
        // `.playback` sounds with the silent switch on. Apps can't raise the system volume, so the
        // tone plays at full player volume and stays as loud as the owner's volume setting allows.
        try? session.setCategory(.playback)
        try? session.setActive(true)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.outputNode.outputFormat(forBus: 0).sampleRate, channels: 1)!
        let node = Self.makeTone(sampleRate: format.sampleRate)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        try? engine.start()
        tone = node
    }

    func stop() {
        guard isSounding else { return }
        isSounding = false
        engine.stop()
        if let tone { engine.detach(tone) }
        tone = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Face ID, Touch ID or the passcode: only the owner can silence it from the phone.
    func stopAsOwner() async {
        let context = LAContext()
        // A phone without a passcode has nothing to check against, and a thief already has it all.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            stop()
            return
        }
        let passed = try? await context.evaluatePolicy(
            .deviceOwnerAuthentication, localizedReason: "Stop the PTP siren")
        if passed == true { stop() }
    }

    /// Nonisolated, because the audio thread calls the render block.
    private nonisolated static func makeTone(sampleRate: Double) -> AVAudioSourceNode {
        var phase = 0.0
        var elapsed = 0.0
        return AVAudioSourceNode { _, _, frameCount, buffers in
            let output = UnsafeMutableAudioBufferListPointer(buffers)
            for frame in 0..<Int(frameCount) {
                // Two square-wave tones, alternating every half second: loud and hard to ignore.
                let hertz = Int(elapsed * 2).isMultiple(of: 2) ? 960.0 : 770.0
                let sample: Float = phase < .pi ? 0.9 : -0.9
                phase = (phase + 2 * .pi * hertz / sampleRate).truncatingRemainder(dividingBy: 2 * .pi)
                elapsed += 1 / sampleRate
                for buffer in output {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
    }
}
