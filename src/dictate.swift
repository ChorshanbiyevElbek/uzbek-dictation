import SwiftUI
import AVFoundation
import AppKit
import Carbon.HIToolbox
import ApplicationServices
import ServiceManagement

// MARK: - Whisper (rubaiSTT) yadrosi

enum RubaiLog {
    private static let df = ISO8601DateFormatter()
    static func write(_ msg: String) {
        NSLog("[rubai] \(msg)")
        let line = "\(df.string(from: Date())) \(msg)\n"
        let path = NSHomeDirectory() + "/rubai-stt/dictation.log"
        try? FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/rubai-stt",
                                                 withIntermediateDirectories: true)
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
        }
    }
}

private func prepareSamples(_ raw: [Float]) -> [Float] {
    guard !raw.isEmpty else { return raw }
    var peak: Float = 0
    for s in raw { peak = max(peak, abs(s)) }
    guard peak > 0.0001 else { return raw }
    let gain = min(0.95 / peak, 40)   // juda past mikrofon signali uchun
    return raw.map { $0 * gain }
}

final class Whisper {
    static let shared = Whisper()
    private var loaded = false
    private let q = DispatchQueue(label: "rubai.whisper")

    private func modelPath() -> String? {
        if let p = Bundle.main.path(forResource: "ggml-rubaistt", ofType: "bin") { return p }
        let fb = NSHomeDirectory() + "/rubai-stt/models/ggml-rubaistt.bin"
        return FileManager.default.fileExists(atPath: fb) ? fb : nil
    }

    func transcribe(_ samples: [Float], done: @escaping (String) -> Void,
                    fail: @escaping (String) -> Void = { _ in }) {
        q.async {
            if !self.loaded {
                guard let mp = self.modelPath() else {
                    NSLog("[rubai] XATO: model fayli topilmadi (bundle/uy)")
                    DispatchQueue.main.async { fail("Model fayli topilmadi") }; return
                }
                let rc = rubai_load(mp)
                NSLog("[rubai] rubai_load(\(mp)) = \(rc)")
                guard rc == 0 else {
                    DispatchQueue.main.async { fail("Model yuklanmadi (kod \(rc))") }; return
                }
                self.loaded = true
            }
            let threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))
            var text = ""
            samples.withUnsafeBufferPointer { buf in
                if let c = rubai_transcribe(buf.baseAddress, Int32(buf.count), threads) {
                    text = String(cString: c).trimmingCharacters(in: .whitespacesAndNewlines)
                    rubai_free_str(c)
                }
            }
            DispatchQueue.main.async { done(text) }
        }
    }

    func unload() { q.async { if self.loaded { rubai_unload(); self.loaded = false } } }
    var isLoaded: Bool { q.sync { loaded } }
}

// MARK: - Mikrofon (16kHz mono float32)

final class Recorder {
    private var engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: 16000, channels: 1, interleaved: false)!
    private var samples: [Float] = []
    private let lock = NSLock()
    private(set) var isRecording = false

    func start(_ cb: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: cb(begin())
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                DispatchQueue.main.async { cb(ok ? self.begin() : false) }
            }
        default: cb(false)
        }
    }

    private func begin() -> Bool {
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()
        // Har yozishda YANGI engine — login'da/qurilma o'zgarganda qotib qolgan
        // (jim, "musiqa") holatdan saqlaydi.
        engine = AVAudioEngine()
        let input = engine.inputNode
        let hw = input.outputFormat(forBus: 0)
        guard hw.sampleRate > 0 else { return false }
        converter = AVAudioConverter(from: hw, to: target)
        input.installTap(onBus: 0, bufferSize: 4096, format: hw) { [weak self] buf, _ in
            guard let self = self, let conv = self.converter else { return }
            let ratio = self.target.sampleRate / hw.sampleRate
            let cap = AVAudioFrameCount(Double(buf.frameLength) * ratio) + 1024
            guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: cap) else { return }
            var fed = false; var err: NSError?
            conv.convert(to: out, error: &err) { _, s in
                if fed { s.pointee = .noDataNow; return nil }
                fed = true; s.pointee = .haveData; return buf
            }
            if let ch = out.floatChannelData {
                let n = Int(out.frameLength)
                self.lock.lock()
                self.samples.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: n))
                self.lock.unlock()
            }
        }
        engine.prepare()
        do { try engine.start() } catch { return false }
        isRecording = true
        return true
    }

    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        lock.lock(); let s = samples; lock.unlock()
        return s
    }
}

// MARK: - Suzuvchi overlay oyna (fokusni o'g'irlamaydi)

final class Overlay {
    private var panel: NSPanel?
    private let W: CGFloat = 320
    private let H: CGFloat = 56
    private let PH: CGFloat = 110

    func show(_ text: String, recording: Bool) {
        let v = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        v.material = .hudWindow; v.blendingMode = .behindWindow; v.state = .active
        v.wantsLayer = true; v.layer?.cornerRadius = 14; v.layer?.masksToBounds = true
        let ic = labelField(frame: NSRect(x: 16, y: (H - 26) / 2, width: 26, height: 26),
                            fontSize: 20, alignment: .center)
        ic.stringValue = recording ? "🔴" : "✍️"
        let lb = labelField(frame: NSRect(x: 50, y: (H - 18) / 2, width: W - 66, height: 18),
                            fontSize: 14)
        lb.stringValue = text
        v.addSubview(ic); v.addSubview(lb)
        showPanel(v, height: H)
    }

    func showProgress(fileName: String, progress: Double, status: String) {
        let v = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: W, height: PH))
        v.material = .hudWindow; v.blendingMode = .behindWindow; v.state = .active
        v.wantsLayer = true; v.layer?.cornerRadius = 14; v.layer?.masksToBounds = true
        let ic = labelField(frame: NSRect(x: 14, y: PH - 36, width: 22, height: 22), fontSize: 16)
        ic.stringValue = "📁"
        let fn = labelField(frame: NSRect(x: 42, y: PH - 38, width: W - 56, height: 18), fontSize: 13)
        fn.stringValue = fileName
        fn.lineBreakMode = .byTruncatingMiddle
        fn.textColor = .labelColor
        let pb = NSProgressIndicator(frame: NSRect(x: 18, y: PH - 72, width: W - 36, height: 12))
        pb.isIndeterminate = false
        pb.minValue = 0; pb.maxValue = 1; pb.doubleValue = progress
        pb.controlSize = .small; pb.isBezeled = false
        let st = labelField(frame: NSRect(x: 18, y: PH - 92, width: W - 36, height: 14), fontSize: 11)
        st.stringValue = status
        st.textColor = .secondaryLabelColor
        v.addSubview(ic); v.addSubview(fn); v.addSubview(pb); v.addSubview(st)
        showPanel(v, height: PH)
    }

    func showResult(_ text: String) {
        let maxW: CGFloat = 500
        let w = min(maxW, text.isEmpty ? W : max(W, min(CGFloat(text.count) * 8, maxW)))
        let lineH: CGFloat = 18
        let textH = max(H, lineH * min(CGFloat(ceil(Double(text.count) / 40)), 4) + 24)
        let v = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: textH))
        v.material = .hudWindow; v.blendingMode = .behindWindow; v.state = .active
        v.wantsLayer = true; v.layer?.cornerRadius = 14; v.layer?.masksToBounds = true
        let ic = labelField(frame: NSRect(x: 14, y: textH - 32, width: 22, height: 22), fontSize: 16)
        ic.stringValue = "✅"
        let lb = labelField(frame: NSRect(x: 42, y: 12, width: w - 56, height: textH - 24),
                            fontSize: 13)
        lb.stringValue = text
        lb.lineBreakMode = .byWordWrapping
        lb.textColor = .labelColor
        v.addSubview(ic); v.addSubview(lb)
        showPanel(v, height: textH)
    }

    func hide() { panel?.orderOut(nil) }

    private func showPanel(_ content: NSView, height: CGFloat) {
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: W, height: height),
                            styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
            p.level = .floating; p.isFloatingPanel = true; p.hidesOnDeactivate = false
            p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = true
            panel = p
        }
        panel!.contentView = content
        panel!.setContentSize(content.frame.size)
        if let scr = NSScreen.main {
            let f = scr.visibleFrame
            panel!.setFrameOrigin(NSPoint(x: f.midX - content.frame.width / 2, y: f.minY + 140))
        }
        panel!.orderFrontRegardless()
    }

    private func labelField(frame: NSRect, fontSize: CGFloat, alignment: NSTextAlignment = .left) -> NSTextField {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: fontSize, weight: .semibold)
        f.isBezeled = false; f.isEditable = false; f.drawsBackground = false
        f.alignment = alignment; f.textColor = .secondaryLabelColor
        f.frame = frame
        return f
    }
}

// MARK: - Fayl transkripsiyasi (audio/video → matn)

final class FileTranscriber {
    private let overlay = Overlay()
    private var isRunning = false

    func selectAndTranscribe() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .movie, .mpeg4Audio, .wav, .mp3]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Transkripsiya uchun audio yoki video faylni tanlang"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        transcribeFile(url)
    }

    func transcribeFile(_ url: URL) {
        guard !isRunning else { return }
        isRunning = true
        let name = url.lastPathComponent
        overlay.showProgress(fileName: name, progress: 0, status: "Tayyorlanmoqda…")
        let q = DispatchQueue.global(qos: .userInitiated)
        q.async { [weak self] in self?.extractAndTranscribe(url) }
    }

    private func extractAndTranscribe(_ url: URL) {
        let name = url.lastPathComponent
        let asst = AVAsset(url: url)
        guard let track = asst.tracks(withMediaType: .audio).first else {
            fail("\(name): audio track topilmadi"); return
        }
        let dur = CMTimeGetSeconds(asst.duration)
        guard dur > 0 else { fail("\(name): fayl bo'sh"); return }
        guard dur < 7200 else { fail("\(name): 2 soatdan katta fayl qo'llab-quvvatlanmaydi"); return }

        let outS: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true, AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16000, AVLinearPCMIsNonInterleaved: false
        ]
        guard let rdr = try? AVAssetReader(asset: asst) else {
            fail("\(name): fayl ochilmadi"); return
        }
        let outp = AVAssetReaderTrackOutput(track: track, outputSettings: outS)
        guard rdr.canAdd(outp) else { fail("\(name): audio o'qilmadi"); return }
        rdr.add(outp)

        progress(name, p: 0, s: "Audio ajratilmoqda…")
        rdr.startReading()
        var samps = [Float]()
        var lastP: Double = 0
        while rdr.status == .reading {
            guard let buf = outp.copyNextSampleBuffer() else { break }
            defer { CMSampleBufferInvalidate(buf) }
            guard let bb = CMSampleBufferGetDataBuffer(buf) else { continue }
            var len: Int = 0; var ptr: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(bb, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &len, dataPointerOut: &ptr)
            if let p2 = ptr {
                let cnt = len / MemoryLayout<Float>.size
                let fp = p2.withMemoryRebound(to: Float.self, capacity: cnt) { $0 }
                samps.append(contentsOf: UnsafeBufferPointer(start: fp, count: cnt))
            }
            let pts = CMTimeGetSeconds(buf.presentationTimeStamp)
            if dur > 0 { let p = min(pts / dur, 1.0); if p - lastP > 0.05 { lastP = p; progress(name, p: p, s: "Audio ajratilmoqda…") } }
        }
        guard rdr.status == .completed else { fail("\(name): o'qish xatosi"); return }
        RubaiLog.write("fayl \(name): \(samps.count) samples (\(String(format: "%.1f", Double(samps.count)/16000))s)")

        progress(name, p: 1, s: "Transkripsiya qilinmoqda…")
        let prepared = prepareSamples(samps)
        let sem = DispatchSemaphore(value: 0)
        var text = ""; var err = ""
        Whisper.shared.transcribe(prepared, done: { text = $0; sem.signal() }, fail: { err = $0; sem.signal() })
        sem.wait()

        DispatchQueue.main.async {
            self.isRunning = false
            if !err.isEmpty { self.fail("\(name): \(err)"); return }
            if text.isEmpty { self.fail("\(name): matn aniqlanmadi"); return }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            let short = text.count > 200 ? String(text.prefix(200)) + "…" : text
            self.overlay.showResult("\(name): \"\(short)\"")

            let saveName = (name as NSString).deletingPathExtension + "_rubai.txt"
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { self.overlay.hide() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.offerSave(text, name: saveName) }
        }
    }

    private func progress(_ name: String, p: Double, s: String) {
        DispatchQueue.main.async { self.overlay.showProgress(fileName: name, progress: p, status: s) }
    }

    private func fail(_ msg: String) {
        DispatchQueue.main.async {
            self.isRunning = false
            self.overlay.show("⚠️ \(msg)", recording: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { self.overlay.hide() }
        }
    }

    private func offerSave(_ text: String, name: String) {
        let p = NSSavePanel()
        p.title = "Transkripsiyani saqlash"
        p.nameFieldStringValue = name
        p.message = "Matn clipboard'ga ko'chirildi. Faylga saqlaysizmi?"
        guard p.runModal() == .OK, let url = p.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Matnni faol input'ga kiritish (clipboard + ⌘V)

enum Inserter {
    /// Matnni clipboard'ga qo'yadi va ⌘V yuboradi. Accessibility yo'q bo'lsa false.
    @discardableResult
    static func insert(_ text: String) -> Bool {
        RubaiLog.write("insert: len=\(text.count) AXTrusted=\(AXIsProcessTrusted())")
        guard !text.isEmpty else { RubaiLog.write("insert: matn bo'sh"); return false }
        guard AXIsProcessTrusted() else { RubaiLog.write("insert: Accessibility yo'q"); return false }
        let pb = NSPasteboard.general
        let old = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        RubaiLog.write("⌘V yuborildi (down=\(down != nil) up=\(up != nil))")
        if let old = old {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                pb.clearContents(); pb.setString(old, forType: .string)
            }
        }
        return true
    }
}

// MARK: - Hotkey sozlamasi (UserDefaults'da saqlanadi)

struct HotKeyConfig {
    var keyCode: UInt32          // virtual key code (masalan kVK_ANSI_D)
    var carbonModifiers: UInt32  // controlKey | optionKey | ...
    var label: String            // ekranda ko'rsatiladigan tugma nomi, masalan "D"

    static let `default` = HotKeyConfig(keyCode: UInt32(kVK_ANSI_D),
                                        carbonModifiers: UInt32(controlKey | optionKey),
                                        label: "D")

    // Ekranda ko'rinishi, masalan "⌃⌥D"
    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + label
    }
}

enum HotKeyStore {
    private static let d = UserDefaults.standard
    static func load() -> HotKeyConfig {
        guard d.object(forKey: "hk.keyCode") != nil else { return .default }
        return HotKeyConfig(keyCode: UInt32(d.integer(forKey: "hk.keyCode")),
                            carbonModifiers: UInt32(d.integer(forKey: "hk.mods")),
                            label: d.string(forKey: "hk.label") ?? "?")
    }
    static func save(_ c: HotKeyConfig) {
        d.set(Int(c.keyCode), forKey: "hk.keyCode")
        d.set(Int(c.carbonModifiers), forKey: "hk.mods")
        d.set(c.label, forKey: "hk.label")
    }
}

// NSEvent modifier'larini Carbon maskasiga o'girish
func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.control) { m |= UInt32(controlKey) }
    if flags.contains(.option)  { m |= UInt32(optionKey) }
    if flags.contains(.shift)   { m |= UInt32(shiftKey) }
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    return m
}

// keyDown hodisasidan tugmaning ko'rinadigan nomini olish
func keyLabel(for event: NSEvent) -> String {
    let special: [UInt16: String] = [
        UInt16(kVK_Space): "Space", UInt16(kVK_Return): "↩", UInt16(kVK_Tab): "⇥",
        UInt16(kVK_Escape): "⎋", UInt16(kVK_Delete): "⌫", UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Home): "↖", UInt16(kVK_End): "↘", UInt16(kVK_PageUp): "⇞", UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]
    if let s = special[event.keyCode] { return s }
    if let c = event.charactersIgnoringModifiers, !c.isEmpty,
       c.rangeOfCharacter(from: .controlCharacters) == nil {
        return c.uppercased()
    }
    return "Key\(event.keyCode)"
}

// MARK: - Global hotkey (Carbon) -> Notification

extension Notification.Name { static let rubaiHotkey = Notification.Name("rubaiHotkey") }

private func hotkeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ ud: UnsafeMutableRawPointer?) -> OSStatus {
    NotificationCenter.default.post(name: .rubaiHotkey, object: nil)
    return noErr
}

final class HotKey {
    private var ref: EventHotKeyRef?
    private var installed = false

    // Hodisa qabul qiluvchini bir marta o'rnatib, hozirgi sozlamani qo'llaydi
    func install() {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let s1 = InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &spec, nil, nil)
            NSLog("[rubai] hotkey handler o'rnatildi: \(s1) (0 = OK)")
            installed = true
        }
        apply(HotKeyStore.load())
    }

    // Eski tugmani bekor qilib, yangisini ro'yxatdan o'tkazadi
    func apply(_ c: HotKeyConfig) {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
        let id = EventHotKeyID(signature: OSType(0x52535454), id: 1) // 'RSTT'
        let s = RegisterEventHotKey(c.keyCode, c.carbonModifiers, id,
                                    GetApplicationEventTarget(), 0, &ref)
        NSLog("[rubai] hotkey ro'yxatdan o'tkazildi \(c.displayString): \(s) (0 = OK)")
    }
}

// MARK: - Sozlamalar oynasi (yangi tugmani yozib olish)

final class SettingsWindow {
    private var window: NSWindow?
    private var monitor: Any?
    private var recordButton: NSButton!
    private var hintLabel: NSTextField!
    private var current: HotKeyConfig
    private var recording = false
    var onChange: ((HotKeyConfig) -> Void)?

    init(_ c: HotKeyConfig) { current = c }

    func update(_ c: HotKeyConfig) { current = c; refreshButton() }

    func show() {
        if window == nil { build() }
        stopRecording()
        refreshButton()
        NSApp.activate(ignoringOtherApps: true)
        window!.center()
        window!.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "RubaiSTT — Sozlamalar"
        w.isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))

        let title = NSTextField(labelWithString: "Diktovka tugmasi")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.frame = NSRect(x: 24, y: 134, width: 312, height: 20)
        v.addSubview(title)

        recordButton = NSButton(title: current.displayString, target: self, action: #selector(toggleRecord))
        recordButton.bezelStyle = .rounded
        recordButton.font = .systemFont(ofSize: 18, weight: .medium)
        recordButton.frame = NSRect(x: 24, y: 84, width: 312, height: 40)
        v.addSubview(recordButton)

        hintLabel = NSTextField(labelWithString: "Tugmani o'zgartirish uchun bosing.")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.frame = NSRect(x: 24, y: 56, width: 312, height: 16)
        v.addSubview(hintLabel)

        let reset = NSButton(title: "Standartga qaytarish (⌃⌥D)", target: self, action: #selector(resetDefault))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 24, y: 16, width: 312, height: 28)
        v.addSubview(reset)

        w.contentView = v
        window = w
    }

    private func refreshButton() {
        recordButton.title = recording ? "Tugmani bosing…" : current.displayString
        hintLabel.stringValue = recording
            ? "Kamida bitta modifier (⌃ ⌥ ⌘ ⇧) + tugma. Bekor qilish: ⎋"
            : "Tugmani o'zgartirish uchun bosing."
    }

    @objc private func toggleRecord() {
        if recording { stopRecording() } else { startRecording() }
        refreshButton()
    }

    @objc private func resetDefault() {
        stopRecording()
        current = .default
        refreshButton()
        onChange?(current)
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            // ⎋ — bekor qilish
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording(); self.refreshButton(); return nil
            }
            let mods = carbonModifiers(from: event.modifierFlags)
            // Kamida bitta modifier shart (aks holda oddiy tugma global qotib qoladi)
            guard mods != 0 else {
                self.hintLabel.stringValue = "Kamida bitta modifier (⌃ ⌥ ⌘ ⇧) kerak!"
                return nil
            }
            let cfg = HotKeyConfig(keyCode: UInt32(event.keyCode),
                                   carbonModifiers: mods,
                                   label: keyLabel(for: event))
            self.current = cfg
            self.stopRecording()
            self.refreshButton()
            self.onChange?(cfg)
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Login'da ishga tushirish (SMAppService)

enum LoginItem {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if on { try SMAppService.mainApp.register() }
            else  { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            NSLog("[rubai] login item xato: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Xush kelibsiz / ruxsat onboarding oynasi (birinchi ishga tushishda)

final class WelcomeWindow {
    private var window: NSWindow?
    private var statusTimer: Timer?
    private var micDot: NSTextField!
    private var axDot: NSTextField!
    var hotkeyText: String = "⌃⌥D"

    func show() {
        if window == nil { build() }
        refreshStatus()
        NSApp.activate(ignoringOtherApps: true)
        window!.center()
        window!.makeKeyAndOrderFront(nil)
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    private func build() {
        let W: CGFloat = 460, H: CGFloat = 420
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "RubaiSTT Diktovka"
        w.isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))

        // Ikona
        let iconView = NSImageView(frame: NSRect(x: (W - 72) / 2, y: H - 96, width: 72, height: 72))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        v.addSubview(iconView)

        let title = NSTextField(labelWithString: "Xush kelibsiz!")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.alignment = .center
        title.frame = NSRect(x: 0, y: H - 130, width: W, height: 26)
        v.addSubview(title)

        let sub = NSTextField(labelWithString: "Istalgan joyda \(hotkeyText) bosing → o'zbekcha gapiring → matn yoziladi.")
        sub.font = .systemFont(ofSize: 12)
        sub.textColor = .secondaryLabelColor
        sub.alignment = .center
        sub.frame = NSRect(x: 20, y: H - 152, width: W - 40, height: 18)
        v.addSubview(sub)

        // 1-qadam: Mikrofon
        micDot = stepRow(in: v, y: H - 210,
                         title: "1. Mikrofon ruxsati",
                         desc: "Ovozingizni eshitish uchun.",
                         button: "Ruxsat so'rash", action: #selector(askMic))
        // 2-qadam: Accessibility
        axDot = stepRow(in: v, y: H - 270,
                        title: "2. Accessibility ruxsati",
                        desc: "Matnni faol maydonga yozish uchun (⌘V).",
                        button: "Sozlamani ochish", action: #selector(openAX))

        // Login'da ishga tushirish
        let loginCheck = NSButton(checkboxWithTitle: "Kompyuter yonganda avtomatik ishga tushsin",
                                  target: self, action: #selector(toggleLogin(_:)))
        loginCheck.state = LoginItem.isEnabled ? .on : .off
        loginCheck.frame = NSRect(x: 30, y: 70, width: W - 60, height: 20)
        v.addSubview(loginCheck)

        let done = NSButton(title: "Boshladik!", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.frame = NSRect(x: W - 150, y: 20, width: 120, height: 32)
        v.addSubview(done)

        w.contentView = v
        window = w
    }

    // Bitta qadam qatori: holat nuqtasi + sarlavha + tugma. Holat nuqtasini qaytaradi.
    private func stepRow(in parent: NSView, y: CGFloat, title: String, desc: String,
                         button: String, action: Selector) -> NSTextField {
        let dot = NSTextField(labelWithString: "○")
        dot.font = .systemFont(ofSize: 16)
        dot.frame = NSRect(x: 30, y: y, width: 22, height: 22)
        parent.addSubview(dot)

        let t = NSTextField(labelWithString: title)
        t.font = .systemFont(ofSize: 13, weight: .semibold)
        t.frame = NSRect(x: 54, y: y + 4, width: 240, height: 18)
        parent.addSubview(t)

        let d = NSTextField(labelWithString: desc)
        d.font = .systemFont(ofSize: 11)
        d.textColor = .secondaryLabelColor
        d.frame = NSRect(x: 54, y: y - 14, width: 260, height: 16)
        parent.addSubview(d)

        let b = NSButton(title: button, target: self, action: action)
        b.bezelStyle = .rounded
        b.frame = NSRect(x: parent.frame.width - 160, y: y - 4, width: 130, height: 28)
        parent.addSubview(b)
        return dot
    }

    private func refreshStatus() {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        micDot.stringValue = mic ? "✅" : "○"
        axDot.stringValue = AXIsProcessTrusted() ? "✅" : "○"
    }

    @objc private func askMic() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            DispatchQueue.main.async { self.refreshStatus() }
        }
    }

    @objc private func openAX() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        LoginItem.set(sender.state == .on)
        sender.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func closeWindow() {
        statusTimer?.invalidate(); statusTimer = nil
        window?.close()
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let rec = Recorder()
    private let overlay = Overlay()
    private let fileXcriber = FileTranscriber()
    private let hotkey = HotKey()
    private var idleTimer: Timer?
    private var hkConfig = HotKeyStore.load()
    private var dictateItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private lazy var settings: SettingsWindow = {
        let s = SettingsWindow(hkConfig)
        s.onChange = { [weak self] cfg in self?.applyHotKey(cfg) }
        return s
    }()
    private lazy var welcome: WelcomeWindow = {
        let w = WelcomeWindow()
        w.hotkeyText = hkConfig.displayString
        return w
    }()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar (Dock'da yo'q)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "rubaiSTT")
        let menu = NSMenu()
        dictateItem = NSMenuItem(title: "Diktovka  (\(hkConfig.displayString))", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(dictateItem)
        menu.addItem(NSMenuItem(title: "Fayl transkripsiyasi…", action: #selector(openFileTranscribe), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sozlamalar…", action: #selector(openSettings), keyEquivalent: ","))
        loginItem = NSMenuItem(title: "Login'da ishga tushirish", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Accessibility ruxsatini ochish", action: #selector(openAX), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Yo'riqnoma…", action: #selector(openWelcome), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Chiqish", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        hotkey.install()
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: .rubaiHotkey, object: nil)

        // Birinchi ishga tushish — onboarding oynasi; aks holda jim Accessibility tekshiruvi
        let d = UserDefaults.standard
        if !d.bool(forKey: "didOnboard") {
            d.set(true, forKey: "didOnboard")
            LoginItem.set(true)                       // standart: login'da yonsin
            loginItem.state = LoginItem.isEnabled ? .on : .off
            welcome.show()
        } else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }

    @objc private func toggleLogin() {
        LoginItem.set(!LoginItem.isEnabled)
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func openWelcome() {
        welcome.hotkeyText = hkConfig.displayString
        welcome.show()
    }

    // Yangi hotkey'ni qo'llab, saqlab, menyuni yangilaydi
    private func applyHotKey(_ cfg: HotKeyConfig) {
        hkConfig = cfg
        HotKeyStore.save(cfg)
        hotkey.apply(cfg)
        dictateItem.title = "Diktovka  (\(cfg.displayString))"
        settings.update(cfg)
    }

    @objc private func openSettings() { settings.show() }

    @objc private func openFileTranscribe() { fileXcriber.selectAndTranscribe() }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        fileXcriber.transcribeFile(URL(fileURLWithPath: filename))
        return true
    }

    @objc private func openAX() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func finishTranscription(_ text: String, samples: [Float]) {
        let secs = Double(samples.count) / 16000.0
        RubaiLog.write("natija: '\(text)' len=\(text.count) audio=\(String(format: "%.1f", secs))s")

        if text.isEmpty {
            let msg = samples.count < 8000
                ? "Juda qisqa — kamida 1 soniya gapiring"
                : "Ovoz aniqlanmadi — balandroq gapiring"
            overlay.show("⚠️ \(msg)", recording: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { self.overlay.hide() }
            scheduleIdleUnload()
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        if Inserter.insert(text) {
            overlay.hide()
        } else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            overlay.show("Matn clipboard'da — ⌘V bosing (Accessibility kerak)", recording: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { self.overlay.hide() }
        }
        scheduleIdleUnload()
    }

    @objc private func toggle() {
        RubaiLog.write("toggle fired, isRecording=\(rec.isRecording)")
        if rec.isRecording {
            let samples = rec.stop()
            let secs = Double(samples.count) / 16000.0
            RubaiLog.write("stopped, samples=\(samples.count) (\(String(format: "%.1f", secs))s)")
            overlay.show("Matnga o'girilmoqda…", recording: false)
            let prepared = prepareSamples(samples)
            Whisper.shared.transcribe(prepared) { [weak self] text in
                self?.finishTranscription(text, samples: samples)
            } fail: { [weak self] msg in
                RubaiLog.write("transcription XATO: \(msg)")
                self?.overlay.show("⚠️ \(msg)", recording: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { self?.overlay.hide() }
            }
        } else {
            rec.start { [weak self] ok in
                RubaiLog.write("record start ok=\(ok)")
                self?.overlay.show(ok ? "Yozilmoqda… (yana \(self?.hkConfig.displayString ?? "⌃⌥D"))" : "Mikrofonga ruxsat yo'q",
                                   recording: ok)
                if !ok { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.overlay.hide() } }
            }
        }
    }

    private func scheduleIdleUnload() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { _ in
            Whisper.shared.unload()   // 3 daqiqa ishlatilmasa RAM bo'shaydi
        }
    }

    @objc private func quit() { rubai_unload(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ n: Notification) { rubai_unload() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
