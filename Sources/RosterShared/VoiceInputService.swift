import AVFoundation
import Foundation
import Speech

@MainActor
package final class VoiceInputService {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    package func start(locale: Locale, language: AppLanguage, onText: @escaping @MainActor (String) -> Void) async throws {
        let speechGranted = await requestSpeechAccess()
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        guard speechGranted, micGranted else {
            throw NSError(domain: "Roster.VoiceInput", code: 1, userInfo: [
                NSLocalizedDescriptionKey: L10n(language: language)(.voiceAccessRequired)
            ])
        }

        stop()

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "Roster.VoiceInput", code: 2, userInfo: [
                NSLocalizedDescriptionKey: L10n(language: language)(.voiceLanguageUnavailable)
            ])
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                Task { @MainActor in
                    onText(result.bestTranscription.formattedString)
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stop()
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    package func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func requestSpeechAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
