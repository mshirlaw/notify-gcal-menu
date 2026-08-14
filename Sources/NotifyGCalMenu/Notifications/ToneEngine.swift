import AVFoundation

/// Synthesizes a short two-tone chime, mirroring notify-gcal's Web Audio chime, so a
/// distinct sound plays even if System Settings has the default notification sound muted.
final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100

    private init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func playChime() {
        guard let buffer = chimeBuffer() else { return }
        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer)
            player.play()
        } catch {
            // Best-effort: the notification banner and its default sound still convey the alert.
        }
    }

    private func chimeBuffer() -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let tones: [(frequency: Double, startTime: Double, duration: Double)] = [
            (880, 0, 0.15),
            (1320, 0.15, 0.2),
        ]
        let totalDuration = 0.35
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        for tone in tones {
            let startFrame = Int(tone.startTime * sampleRate)
            let toneFrameCount = Int(tone.duration * sampleRate)
            let fadeInFrames = Int(0.02 * sampleRate)

            for i in 0..<toneFrameCount {
                let frame = startFrame + i
                guard frame < Int(frameCount) else { break }
                let time = Double(i) / sampleRate
                let amplitude: Double
                if i < fadeInFrames {
                    amplitude = 0.2 * (Double(i) / Double(fadeInFrames))
                } else {
                    let fadeOutProgress = (time - 0.02) / (tone.duration - 0.02)
                    amplitude = 0.2 * max(0, 1 - fadeOutProgress)
                }
                let sample = amplitude * sin(2 * .pi * tone.frequency * time)
                channelData[frame] += Float(sample)
            }
        }

        return buffer
    }
}
