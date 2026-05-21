import AppKit
import ApplicationServices
import AVFoundation
import Carbon.HIToolbox
import Speech

func ztLog(_ message: String) {
    NSLog("[ZenTap] \(message)")
}

enum ZenTapState: Equatable {
    case idle
    case requestingPermission
    case listening
    case finishing
    case notice(String)
    case error(String)
}

enum ZenTapLocale: String, CaseIterable {
    case chinese = "zh_CN"
    case english = "en_US"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var title: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    var shortTitle: String {
        switch self {
        case .chinese:
            return "中"
        case .english:
            return "EN"
        }
    }
}

enum ZenTapPanelSize: String, CaseIterable {
    case small
    case medium
    case large

    var title: String {
        switch self {
        case .small:
            return "小"
        case .medium:
            return "中"
        case .large:
            return "大"
        }
    }

    var noticeTitle: String {
        "\(title)尺寸"
    }

    var scale: CGFloat {
        switch self {
        case .small:
            return 0.78
        case .medium:
            return 0.90
        case .large:
            return 1.0
        }
    }

    var windowSize: NSSize {
        NSSize(width: ZenTapView.designSize.width * scale, height: ZenTapView.designSize.height * scale)
    }

    var zenWindowSize: NSSize {
        let side: CGFloat
        switch self {
        case .small:
            side = 84
        case .medium:
            side = 96
        case .large:
            side = 110
        }
        return NSSize(width: side, height: side)
    }
}

enum ZenTapVisualMode {
    case standard
    case zen
}

enum ZenTapInputMode: String, CaseIterable {
    case appleSpeech
    case doubaoShortcut

    var title: String {
        switch self {
        case .appleSpeech:
            return "系统离线识别"
        case .doubaoShortcut:
            return "豆包快捷键"
        }
    }

    var idleTitle: String {
        switch self {
        case .appleSpeech:
            return "轻触输入"
        case .doubaoShortcut:
            return "轻触豆包"
        }
    }
}

enum VoiceShortcutPreset: String, CaseIterable {
    case functionKey
    case optionSpace
    case controlSpace
    case commandShiftSpace
    case f5

    var title: String {
        switch self {
        case .functionKey:
            return "fn"
        case .optionSpace:
            return "⌥ Space"
        case .controlSpace:
            return "⌃ Space"
        case .commandShiftSpace:
            return "⌘ ⇧ Space"
        case .f5:
            return "F5"
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .functionKey:
            return CGKeyCode(kVK_Function)
        case .optionSpace, .controlSpace, .commandShiftSpace:
            return CGKeyCode(kVK_Space)
        case .f5:
            return CGKeyCode(kVK_F5)
        }
    }

    var flags: CGEventFlags {
        switch self {
        case .functionKey:
            return .maskSecondaryFn
        case .optionSpace:
            return .maskAlternate
        case .controlSpace:
            return .maskControl
        case .commandShiftSpace:
            return CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue)
        case .f5:
            return []
        }
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ZenTapView: NSView {
    static let designSize = NSSize(width: 156, height: 176)
    static let zenDesignSize = NSSize(width: 96, height: 96)

    var onToggle: (() -> Void)?
    var onShowMenu: ((NSPoint) -> Void)?

    var state: ZenTapState = .idle {
        didSet {
            needsDisplay = true
            updateAnimation()
        }
    }

    var locale: ZenTapLocale = .chinese {
        didSet { needsDisplay = true }
    }

    var transcript: String = "" {
        didSet { needsDisplay = true }
    }

    var inputLevel: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var visualMode: ZenTapVisualMode = .standard {
        didSet { needsDisplay = true }
    }

    var idleTitle: String = "轻触输入" {
        didSet { needsDisplay = true }
    }

    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var didDrag = false
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        toolTip = "左键开始或结束听写；右键打开菜单"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        animationTimer?.invalidate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let deltaX = mouse.x - dragStartMouse.x
        let deltaY = mouse.y - dragStartMouse.y
        if abs(deltaX) > 3 || abs(deltaY) > 3 {
            didDrag = true
        }
        window.setFrameOrigin(NSPoint(x: dragStartOrigin.x + deltaX, y: dragStartOrigin.y + deltaY))
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onToggle?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onShowMenu?(convert(event.locationInWindow, from: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let designSize = visualMode == .zen ? Self.zenDesignSize : Self.designSize
        let scale = min(bounds.width / designSize.width, bounds.height / designSize.height)
        let drawingSize = NSSize(width: designSize.width * scale, height: designSize.height * scale)
        let origin = NSPoint(x: bounds.midX - drawingSize.width / 2, y: bounds.midY - drawingSize.height / 2)

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: origin.x, yBy: origin.y)
        transform.scale(by: scale)
        transform.concat()

        let designBounds = NSRect(origin: .zero, size: designSize).insetBy(dx: 0.5, dy: 0.5)
        if visualMode == .zen {
            drawZenMark(in: designBounds)
        } else {
            drawBackground(in: designBounds)
            drawTitle(in: designBounds)
            drawTouchMark(in: designBounds)
            drawStatusText(in: designBounds)
            drawTranscript(in: designBounds)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBackground(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedRed: 0.968, green: 0.945, blue: 0.905, alpha: 0.94).setFill()
        path.fill()

        NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.19, alpha: 0.12).setStroke()
        path.lineWidth = 1
        path.stroke()

        let shadowLine = NSBezierPath()
        shadowLine.move(to: NSPoint(x: rect.minX + 18, y: rect.minY + 41))
        shadowLine.line(to: NSPoint(x: rect.maxX - 18, y: rect.minY + 41))
        NSColor(calibratedRed: 0.19, green: 0.24, blue: 0.20, alpha: 0.08).setStroke()
        shadowLine.lineWidth = 1
        shadowLine.stroke()
    }

    private func drawTitle(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.105, blue: 0.085, alpha: 0.88),
            .paragraphStyle: paragraph
        ]
        "指言 ZenTap".draw(in: NSRect(x: rect.minX + 12, y: rect.maxY - 30, width: rect.width - 24, height: 18), withAttributes: titleAttributes)

        let badgeRect = NSRect(x: rect.maxX - 42, y: rect.maxY - 31, width: 26, height: 18)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7)
        NSColor(calibratedRed: 0.48, green: 0.42, blue: 0.26, alpha: 0.15).setFill()
        badgePath.fill()

        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.19, green: 0.16, blue: 0.10, alpha: 0.78),
            .paragraphStyle: paragraph
        ]
        locale.shortTitle.draw(in: badgeRect.insetBy(dx: 1, dy: 2), withAttributes: badgeAttributes)
    }

    private func drawTouchMark(in rect: NSRect) {
        let center = NSPoint(x: rect.midX, y: rect.maxY - 78)
        drawPorcelainLake(center: center, radius: 32)

        let sway = state == .listening ? sin(animationPhase * 1.45) * 13 + inputLevel * 4 : 0
        let lift = state == .listening ? sin(animationPhase * 1.2) * 1.7 : 0
        let angle: CGFloat
        switch state {
        case .listening:
            angle = -15 + sway
        case .finishing, .requestingPermission:
            angle = -7
        default:
            angle = -18
        }

        let stemColor: NSColor = state == .listening
            ? NSColor(calibratedRed: 0.61, green: 0.18, blue: 0.12, alpha: 0.78)
            : NSColor(calibratedRed: 0.20, green: 0.31, blue: 0.22, alpha: 0.68)
        drawBambooLeaf(center: NSPoint(x: center.x + 1, y: center.y + lift), angle: angle, stemColor: stemColor)
    }

    private func drawZenMark(in rect: NSRect) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 38
        drawPorcelainLake(center: center, radius: radius)

        let sway = state == .listening ? sin(animationPhase * 1.45) * 14 + inputLevel * 5 : 0
        let lift = state == .listening ? sin(animationPhase * 1.2) * 1.8 : 0
        let angle: CGFloat
        switch state {
        case .listening:
            angle = -15 + sway
        case .finishing, .requestingPermission:
            angle = -7
        default:
            angle = -18
        }

        let stemColor: NSColor = state == .listening
            ? NSColor(calibratedRed: 0.61, green: 0.18, blue: 0.12, alpha: 0.78)
            : NSColor(calibratedRed: 0.20, green: 0.31, blue: 0.22, alpha: 0.68)
        drawBambooLeaf(center: NSPoint(x: center.x + 1, y: center.y + lift), angle: angle, stemColor: stemColor)
    }

    private func drawPorcelainLake(center: NSPoint, radius baseRadius: CGFloat) {
        let pulse = state == .listening ? 1.8 + sin(animationPhase) * 1.25 + inputLevel * 4.5 : 0
        let lakeRect = NSRect(
            x: center.x - baseRadius - pulse,
            y: center.y - baseRadius - pulse,
            width: (baseRadius + pulse) * 2,
            height: (baseRadius + pulse) * 2
        )
        let lakePath = NSBezierPath(ovalIn: lakeRect)

        NSGraphicsContext.saveGraphicsState()
        lakePath.addClip()
        NSGradient(colors: [
            NSColor(calibratedRed: 0.75, green: 0.84, blue: 0.80, alpha: 1),
            NSColor(calibratedRed: 0.53, green: 0.66, blue: 0.61, alpha: 1),
            NSColor(calibratedRed: 0.36, green: 0.48, blue: 0.43, alpha: 1)
        ])?.draw(in: lakeRect, angle: -54)

        let lowerShade = NSBezierPath(ovalIn: lakeRect.offsetBy(dx: 0, dy: -13).insetBy(dx: 7, dy: 4))
        NSColor(calibratedRed: 0.20, green: 0.38, blue: 0.33, alpha: 0.12).setFill()
        lowerShade.fill()

        let porcelainGlow = NSBezierPath(ovalIn: NSRect(x: lakeRect.minX + 14, y: lakeRect.maxY - 26, width: 24, height: 16))
        NSColor(calibratedWhite: 1, alpha: 0.44).setFill()
        porcelainGlow.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedWhite: 1, alpha: 0.54).setStroke()
        lakePath.lineWidth = 1
        lakePath.stroke()

        drawWaterRipples(center: center, radius: baseRadius, pulse: pulse)
    }

    private func drawWaterRipples(center: NSPoint, radius: CGFloat, pulse: CGFloat) {
        let listening = state == .listening
        let ringCount = 3
        for index in 0..<ringCount {
            let phaseOffset = CGFloat(index) * 0.82
            let breath = listening ? (sin(animationPhase * 1.35 + phaseOffset) + 1) / 2 : 0.22
            let inset = CGFloat(7 + index * 8) - breath * (listening ? 4 : 0)
            let alpha = listening ? 0.22 + breath * 0.34 : 0.22 - CGFloat(index) * 0.035
            let rect = NSRect(
                x: center.x - radius + inset - pulse * 0.3,
                y: center.y - radius + inset + CGFloat(index) * 1.1,
                width: (radius - inset + pulse * 0.3) * 2,
                height: max(6, (radius - inset) * 1.04)
            )
            let ripple = NSBezierPath(ovalIn: rect)
            NSColor(calibratedWhite: 1, alpha: alpha).setStroke()
            ripple.lineWidth = index == 0 ? 1.2 : 0.9
            ripple.stroke()
        }

        switch state {
        case .listening:
            let wake = NSBezierPath()
            wake.move(to: NSPoint(x: center.x - 24, y: center.y - 2))
            wake.curve(
                to: NSPoint(x: center.x + 25, y: center.y + 1),
                controlPoint1: NSPoint(x: center.x - 10, y: center.y + 8),
                controlPoint2: NSPoint(x: center.x + 8, y: center.y - 8)
            )
            NSColor(calibratedRed: 0.61, green: 0.18, blue: 0.12, alpha: 0.24).setStroke()
            wake.lineWidth = 1.4
            wake.lineCapStyle = .round
            wake.stroke()
        case .finishing, .requestingPermission:
            let smallRipple = NSBezierPath(ovalIn: NSRect(x: center.x - 21, y: center.y - 7, width: 42, height: 14))
            NSColor(calibratedRed: 0.32, green: 0.48, blue: 0.42, alpha: 0.26).setStroke()
            smallRipple.lineWidth = 1
            smallRipple.stroke()
        default:
            break
        }
    }

    private func drawBambooLeaf(center: NSPoint, angle: CGFloat, stemColor: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: angle)
        transform.concat()

        let shadow = NSBezierPath()
        shadow.move(to: NSPoint(x: -21, y: -1.5))
        shadow.curve(to: NSPoint(x: 25, y: 0), controlPoint1: NSPoint(x: -2, y: -11), controlPoint2: NSPoint(x: 17, y: -7))
        shadow.curve(to: NSPoint(x: -21, y: -1.5), controlPoint1: NSPoint(x: 13, y: 10), controlPoint2: NSPoint(x: -7, y: 7))
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.08, alpha: 0.10).setFill()
        shadow.fill()

        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: -22, y: 0))
        leaf.curve(to: NSPoint(x: 25, y: 0.3), controlPoint1: NSPoint(x: -3, y: -12), controlPoint2: NSPoint(x: 18, y: -7))
        leaf.curve(to: NSPoint(x: -22, y: 0), controlPoint1: NSPoint(x: 13, y: 10), controlPoint2: NSPoint(x: -8, y: 8))
        NSGradient(colors: [
            NSColor(calibratedRed: 0.36, green: 0.49, blue: 0.30, alpha: 1),
            NSColor(calibratedRed: 0.19, green: 0.35, blue: 0.26, alpha: 1)
        ])?.draw(in: leaf, angle: -8)

        let vein = NSBezierPath()
        vein.move(to: NSPoint(x: -17, y: 0.2))
        vein.curve(
            to: NSPoint(x: 19, y: 0.2),
            controlPoint1: NSPoint(x: -4, y: -1.8),
            controlPoint2: NSPoint(x: 9, y: -0.8)
        )
        NSColor(calibratedWhite: 0.96, alpha: 0.42).setStroke()
        vein.lineWidth = 0.9
        vein.lineCapStyle = .round
        vein.stroke()

        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: 22, y: 0.3))
        stem.line(to: NSPoint(x: 31, y: 1.2))
        stemColor.setStroke()
        stem.lineWidth = 1.8
        stem.lineCapStyle = .round
        stem.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawStatusText(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let text: String
        let color: NSColor
        switch state {
        case .idle:
            text = idleTitle
            color = NSColor(calibratedRed: 0.17, green: 0.15, blue: 0.11, alpha: 0.84)
        case .requestingPermission:
            text = "等待授权"
            color = NSColor(calibratedRed: 0.38, green: 0.30, blue: 0.16, alpha: 0.90)
        case .listening:
            text = "正在聆听"
            color = NSColor(calibratedRed: 0.58, green: 0.14, blue: 0.08, alpha: 0.90)
        case .finishing:
            text = "整理文字"
            color = NSColor(calibratedRed: 0.26, green: 0.36, blue: 0.25, alpha: 0.90)
        case .notice(let message):
            text = message
            color = NSColor(calibratedRed: 0.25, green: 0.29, blue: 0.20, alpha: 0.88)
        case .error(let message):
            text = message
            color = NSColor(calibratedRed: 0.58, green: 0.14, blue: 0.08, alpha: 0.92)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(in: NSRect(x: rect.minX + 12, y: rect.minY + 39, width: rect.width - 24, height: 17), withAttributes: attributes)
    }

    private func drawTranscript(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let preview = transcript.isEmpty ? locale.title : transcript
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.14, green: 0.12, blue: 0.09, alpha: transcript.isEmpty ? 0.46 : 0.70),
            .paragraphStyle: paragraph
        ]
        preview.draw(in: NSRect(x: rect.minX + 13, y: rect.minY + 17, width: rect.width - 26, height: 17), withAttributes: attributes)
    }

    private func updateAnimation() {
        let shouldAnimate = state == .listening
        if shouldAnimate, animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.animationPhase += 0.16
                self.needsDisplay = true
            }
        } else if !shouldAnimate {
            animationTimer?.invalidate()
            animationTimer = nil
            animationPhase = 0
            inputLevel = 0
        }
    }
}

final class SpeechController {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var latestTranscript = ""
    private var stopCompletion: ((String) -> Void)?
    private var stopTimer: DispatchWorkItem?
    private var isStopping = false
    private var recognitionGeneration = 0

    var isListening: Bool {
        audioEngine.isRunning
    }

    var hasActiveSession: Bool {
        audioEngine.isRunning || request != nil
    }

    func start(
        locale: ZenTapLocale,
        onStarted: @escaping () -> Void,
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (CGFloat) -> Void,
        onError: @escaping (String) -> Void
    ) {
        ztLog("start requested locale=\(locale.rawValue)")
        requestPermissions { [weak self] allowed, message in
            guard let self else { return }
            guard allowed else {
                ztLog("permission denied: \(message ?? "unknown")")
                onError(message ?? "需要麦克风和语音识别权限")
                return
            }

            self.stopImmediately()
            self.recognitionGeneration += 1
            let generation = self.recognitionGeneration
            self.latestTranscript = ""
            self.isStopping = false

            let recognizer = SFSpeechRecognizer(locale: locale.locale)
            guard let recognizer else {
                ztLog("recognizer unavailable for locale=\(locale.rawValue)")
                onError("无法载入该语言")
                return
            }
            guard recognizer.isAvailable else {
                ztLog("recognizer not available")
                onError("语音识别暂不可用")
                return
            }
            guard recognizer.supportsOnDeviceRecognition else {
                ztLog("on-device asset unavailable for locale=\(locale.rawValue)")
                onError("未安装离线资源")
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            if #available(macOS 13.0, *) {
                request.addsPunctuation = true
            }

            self.recognizer = recognizer
            self.request = request

            let inputNode = self.audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                request.append(buffer)
                let level = Self.normalizedLevel(from: buffer)
                DispatchQueue.main.async {
                    self?.latestTranscript = self?.latestTranscript ?? ""
                    onLevel(level)
                }
            }

            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    guard generation == self.recognitionGeneration else { return }
                    if let result {
                        self.latestTranscript = result.bestTranscription.formattedString
                        ztLog("partial length=\(self.latestTranscript.count) final=\(result.isFinal)")
                        onPartial(self.latestTranscript)
                        if result.isFinal, self.isStopping {
                            self.finishStop()
                        }
                    }

                    if let error, !self.isStopping {
                        ztLog("recognition error: \(error.localizedDescription)")
                        self.stopImmediately()
                        onError(error.localizedDescription)
                    }
                }
            }

            do {
                self.audioEngine.prepare()
                try self.audioEngine.start()
                ztLog("audio engine started")
                onStarted()
            } catch {
                ztLog("audio engine failed: \(error.localizedDescription)")
                self.stopImmediately()
                onError(error.localizedDescription)
            }
        }
    }

    func stop(completion: @escaping (String) -> Void) {
        ztLog("stop requested running=\(audioEngine.isRunning) hasRequest=\(request != nil)")
        guard audioEngine.isRunning || request != nil else {
            completion(latestTranscript)
            return
        }

        isStopping = true
        stopCompletion = completion
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()

        let timer = DispatchWorkItem { [weak self] in
            self?.finishStop()
        }
        stopTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: timer)
    }

    private func finishStop() {
        stopTimer?.cancel()
        stopTimer = nil
        let completion = stopCompletion
        stopCompletion = nil
        let text = latestTranscript
        ztLog("finish stop transcriptLength=\(text.count)")
        stopImmediately()
        completion?(text)
    }

    private func stopImmediately() {
        recognitionGeneration += 1
        isStopping = true
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        isStopping = false
    }

    private func requestPermissions(completion: @escaping (Bool, String?) -> Void) {
        var speechAllowed = false
        var micAllowed = false
        let group = DispatchGroup()

        group.enter()
        SFSpeechRecognizer.requestAuthorization { status in
            speechAllowed = status == .authorized
            group.leave()
        }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { allowed in
            micAllowed = allowed
            group.leave()
        }

        group.notify(queue: .main) {
            if speechAllowed && micAllowed {
                completion(true, nil)
            } else if !speechAllowed && !micAllowed {
                completion(false, "需要语音和麦克风权限")
            } else if !speechAllowed {
                completion(false, "需要语音识别权限")
            } else {
                completion(false, "需要麦克风权限")
            }
        }
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for frame in 0..<frameLength {
            let sample = channelData[frame]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let scaled = min(max((CGFloat(rms) - 0.015) * 18, 0), 1)
        return scaled
    }
}

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataByType[type] = data
                }
            }
            return dataByType
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let pasteboardItems = items.map { dataByType -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dataByType {
                item.setData(data, forType: type)
            }
            return item
        }
        if !pasteboardItems.isEmpty {
            pasteboard.writeObjects(pasteboardItems)
        }
    }
}

final class TextInserter {
    func insert(_ rawText: String, targetApp: NSRunningApplication?, status: @escaping (String) -> Void) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        ztLog("insert requested textLength=\(text.count) target=\(targetApp?.localizedName ?? "nil")")
        guard !text.isEmpty else {
            status("没有听到内容")
            return
        }

        guard isAccessibilityTrusted(prompt: true) else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            openAccessibilitySettings()
            ztLog("accessibility not trusted; copied to pasteboard")
            status("已复制，请授权")
            return
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if let targetApp {
            targetApp.activate(options: [])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.postCommandV()
            ztLog("posted command-v")
            status("已输入")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                snapshot.restore(to: pasteboard)
            }
        }
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func sendShortcut(_ preset: VoiceShortcutPreset) -> Bool {
        ztLog("shortcut requested preset=\(preset.rawValue)")
        guard isAccessibilityTrusted(prompt: true) else {
            openAccessibilitySettings()
            ztLog("accessibility not trusted; shortcut blocked")
            return false
        }

        postKey(preset.keyCode, flags: preset.flags)
        ztLog("posted shortcut \(preset.title)")
        return true
    }

    func sendDoubaoStopAction(_ action: DoubaoStopAction, repeating preset: VoiceShortcutPreset) -> Bool {
        ztLog("doubao stop requested action=\(action.rawValue)")
        guard isAccessibilityTrusted(prompt: true) else {
            openAccessibilitySettings()
            ztLog("accessibility not trusted; stop action blocked")
            return false
        }

        if action == .repeatShortcut {
            postKey(preset.keyCode, flags: preset.flags)
        } else if let keyCode = action.keyCode {
            postKey(keyCode, flags: action.flags)
        }
        ztLog("posted doubao stop action \(action.shortTitle)")
        return true
    }

    private func postCommandV() {
        postKey(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }

    private func postKey(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let speechController = SpeechController()
    private let textInserter = TextInserter()
    private var panel: FloatingPanel!
    private var zenView: ZenTapView!
    private var statusItem: NSStatusItem!
    private var selectedInputMode: ZenTapInputMode = ZenTapInputMode(
        rawValue: UserDefaults.standard.string(forKey: "ZenTapInputMode") ?? ""
    ) ?? .appleSpeech
    private var selectedShortcutPreset: VoiceShortcutPreset = VoiceShortcutPreset(
        rawValue: UserDefaults.standard.string(forKey: "ZenTapVoiceShortcutPreset") ?? ""
    ) ?? .functionKey
    private var selectedDoubaoStopAction: DoubaoStopAction = DoubaoStopAction.resolvedStoredAction(
        UserDefaults.standard.string(forKey: "ZenTapDoubaoStopAction")
    )
    private var selectedLocale: ZenTapLocale = .chinese
    private var selectedPanelSize: ZenTapPanelSize = .small
    private var selectedVisualMode: ZenTapVisualMode = .standard
    private var shortcutBridgeIsListening = false
    private var lastTargetApp: NSRunningApplication?
    private var clearNoticeWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.set(selectedDoubaoStopAction.rawValue, forKey: "ZenTapDoubaoStopAction")
        setupFloatingPanel()
        setupStatusItem()
        observeFrontmostApplications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        resetPanelPosition()
        return true
    }

    private func setupFloatingPanel() {
        let size = currentWindowSize()
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.title = "指言 ZenTap"

        zenView = ZenTapView(frame: NSRect(origin: .zero, size: size))
        zenView.locale = selectedLocale
        zenView.visualMode = selectedVisualMode
        zenView.idleTitle = selectedInputMode.idleTitle
        zenView.onToggle = { [weak self] in
            self?.toggleDictation()
        }
        zenView.onShowMenu = { [weak self] point in
            guard let self else { return }
            self.contextMenu().popUp(positioning: nil, at: point, in: self.zenView)
        }
        panel.contentView = zenView

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = NSPoint(x: visibleFrame.maxX - size.width - 36, y: visibleFrame.midY - size.height / 2)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "指"
        statusItem.button?.toolTip = "指言 ZenTap"
        statusItem.menu = contextMenu()
    }

    private func observeFrontmostApplications() {
        if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastTargetApp = app
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func frontmostApplicationChanged(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        lastTargetApp = app
    }

    private func toggleDictation() {
        if selectedInputMode == .doubaoShortcut {
            toggleShortcutBridge()
            return
        }

        if speechController.hasActiveSession, zenView.state != .finishing {
            stopDictation()
            return
        }

        switch zenView.state {
        case .listening:
            stopDictation()
        case .requestingPermission, .finishing:
            return
        default:
            startDictation()
        }
    }

    private func toggleShortcutBridge() {
        guard zenView.state != .requestingPermission, zenView.state != .finishing else { return }

        clearNoticeWorkItem?.cancel()
        zenView.transcript = doubaoBridgeSubtitle()
        rememberCurrentTargetApp()

        switch DoubaoBridgePlanner.nextAction(isListening: shortcutBridgeIsListening) {
        case .startShortcut:
            guard textInserter.sendShortcut(selectedShortcutPreset) else {
                shortcutBridgeIsListening = false
                showNotice("请授权辅助功能")
                return
            }
            shortcutBridgeIsListening = true
            zenView.state = .listening

        case .stopAction:
            guard textInserter.sendDoubaoStopAction(selectedDoubaoStopAction, repeating: selectedShortcutPreset) else {
                shortcutBridgeIsListening = false
                showNotice("请授权辅助功能")
                return
            }
            shortcutBridgeIsListening = false
            zenView.state = .finishing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, self.selectedInputMode == .doubaoShortcut else { return }
                self.showNotice("豆包输入")
            }
        }
    }

    private func startDictation() {
        clearNoticeWorkItem?.cancel()
        zenView.transcript = ""
        zenView.state = .requestingPermission
        rememberCurrentTargetApp()

        speechController.start(
            locale: selectedLocale,
            onStarted: { [weak self] in
                self?.zenView.state = .listening
            },
            onPartial: { [weak self] text in
                self?.zenView.transcript = text
            },
            onLevel: { [weak self] level in
                self?.zenView.inputLevel = level
            },
            onError: { [weak self] message in
                self?.showError(message)
            }
        )
    }

    private func stopDictation() {
        ztLog("UI stopDictation")
        zenView.state = .finishing
        speechController.stop { [weak self] transcript in
            guard let self else { return }
            self.textInserter.insert(transcript, targetApp: self.lastTargetApp) { [weak self] status in
                self?.showNotice(status)
            }
        }
    }

    private func rememberCurrentTargetApp() {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        lastTargetApp = app
        ztLog("target app=\(app.localizedName ?? app.bundleIdentifier ?? "unknown")")
    }

    private func setInputMode(_ inputMode: ZenTapInputMode) {
        if speechController.hasActiveSession {
            speechController.stop { _ in }
        }
        selectedInputMode = inputMode
        shortcutBridgeIsListening = false
        zenView.idleTitle = inputMode.idleTitle
        zenView.transcript = inputMode == .doubaoShortcut ? doubaoBridgeSubtitle() : ""
        UserDefaults.standard.set(inputMode.rawValue, forKey: "ZenTapInputMode")
        showNotice(inputMode.title)
    }

    private func setShortcutPreset(_ preset: VoiceShortcutPreset) {
        selectedShortcutPreset = preset
        shortcutBridgeIsListening = false
        zenView.transcript = selectedInputMode == .doubaoShortcut ? doubaoBridgeSubtitle() : zenView.transcript
        UserDefaults.standard.set(preset.rawValue, forKey: "ZenTapVoiceShortcutPreset")
        showNotice("快捷键 \(preset.title)")
    }

    private func setDoubaoStopAction(_ action: DoubaoStopAction) {
        selectedDoubaoStopAction = action
        shortcutBridgeIsListening = false
        zenView.transcript = selectedInputMode == .doubaoShortcut ? doubaoBridgeSubtitle() : zenView.transcript
        UserDefaults.standard.set(action.rawValue, forKey: "ZenTapDoubaoStopAction")
        showNotice(action.noticeTitle)
    }

    private func doubaoBridgeSubtitle() -> String {
        "\(selectedShortcutPreset.title) / \(selectedDoubaoStopAction.shortTitle)"
    }

    private func setLocale(_ locale: ZenTapLocale) {
        selectedLocale = locale
        zenView.locale = locale
        showNotice(locale.title)
    }

    private func showNotice(_ message: String) {
        clearNoticeWorkItem?.cancel()
        zenView.state = .notice(message)
        let item = DispatchWorkItem { [weak self] in
            self?.zenView.state = .idle
            self?.zenView.transcript = ""
        }
        clearNoticeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: item)
    }

    private func showError(_ message: String) {
        clearNoticeWorkItem?.cancel()
        zenView.state = .error(message)
        let item = DispatchWorkItem { [weak self] in
            self?.zenView.state = .idle
            self?.zenView.transcript = ""
        }
        clearNoticeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3, execute: item)
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleTitle: String
        if selectedInputMode == .doubaoShortcut {
            toggleTitle = shortcutBridgeIsListening ? "结束豆包语音" : "开始豆包语音"
        } else {
            toggleTitle = zenView?.state == .listening ? "结束听写" : "开始听写"
        }
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(NSMenuItem.separator())

        let inputModeMenuItem = NSMenuItem(title: "输入引擎", action: nil, keyEquivalent: "")
        let inputModeMenu = NSMenu(title: "输入引擎")
        for inputMode in ZenTapInputMode.allCases {
            let item = NSMenuItem(title: inputMode.title, action: #selector(inputModeFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = inputMode.rawValue
            item.state = inputMode == selectedInputMode ? .on : .off
            inputModeMenu.addItem(item)
        }
        inputModeMenuItem.submenu = inputModeMenu
        menu.addItem(inputModeMenuItem)

        let shortcutMenuItem = NSMenuItem(title: "豆包快捷键", action: nil, keyEquivalent: "")
        let shortcutMenu = NSMenu(title: "豆包快捷键")
        for preset in VoiceShortcutPreset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(shortcutFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            item.state = preset == selectedShortcutPreset ? .on : .off
            shortcutMenu.addItem(item)
        }
        shortcutMenuItem.submenu = shortcutMenu
        menu.addItem(shortcutMenuItem)

        let stopActionMenuItem = NSMenuItem(title: "豆包结束方式", action: nil, keyEquivalent: "")
        let stopActionMenu = NSMenu(title: "豆包结束方式")
        for action in DoubaoStopAction.allCases {
            let item = NSMenuItem(title: action.title, action: #selector(stopActionFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action.rawValue
            item.state = action == selectedDoubaoStopAction ? .on : .off
            stopActionMenu.addItem(item)
        }
        stopActionMenuItem.submenu = stopActionMenu
        menu.addItem(stopActionMenuItem)

        menu.addItem(NSMenuItem.separator())

        for locale in ZenTapLocale.allCases {
            let item = NSMenuItem(title: locale.title, action: #selector(languageFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = locale.rawValue
            item.state = locale == selectedLocale ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let sizeMenuItem = NSMenuItem(title: "尺寸", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: "尺寸")
        for panelSize in ZenTapPanelSize.allCases {
            let item = NSMenuItem(title: panelSize.title, action: #selector(sizeFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = panelSize.rawValue
            item.state = panelSize == selectedPanelSize ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)

        menu.addItem(NSMenuItem.separator())

        let zenMode = NSMenuItem(title: "禅意模式", action: #selector(toggleZenMode), keyEquivalent: "")
        zenMode.target = self
        zenMode.state = selectedVisualMode == .zen ? .on : .off
        menu.addItem(zenMode)

        menu.addItem(NSMenuItem.separator())

        let permissions = NSMenuItem(title: "检查辅助功能权限", action: #selector(checkAccessibilityPermission), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        let resetPosition = NSMenuItem(title: "回到屏幕右侧", action: #selector(resetPanelPosition), keyEquivalent: "")
        resetPosition.target = self
        menu.addItem(resetPosition)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "退出 ZenTap", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func toggleFromMenu() {
        toggleDictation()
    }

    @objc private func inputModeFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let inputMode = ZenTapInputMode(rawValue: rawValue)
        else { return }
        setInputMode(inputMode)
        statusItem.menu = contextMenu()
    }

    @objc private func shortcutFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let preset = VoiceShortcutPreset(rawValue: rawValue)
        else { return }
        setShortcutPreset(preset)
        statusItem.menu = contextMenu()
    }

    @objc private func stopActionFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let action = DoubaoStopAction(rawValue: rawValue)
        else { return }
        setDoubaoStopAction(action)
        statusItem.menu = contextMenu()
    }

    @objc private func languageFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let locale = ZenTapLocale(rawValue: rawValue)
        else { return }
        setLocale(locale)
        statusItem.menu = contextMenu()
    }

    @objc private func sizeFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let panelSize = ZenTapPanelSize(rawValue: rawValue)
        else { return }
        setPanelSize(panelSize)
        statusItem.menu = contextMenu()
    }

    @objc private func toggleZenMode() {
        setVisualMode(selectedVisualMode == .zen ? .standard : .zen)
        statusItem.menu = contextMenu()
    }

    @objc private func checkAccessibilityPermission() {
        if textInserter.isAccessibilityTrusted(prompt: true) {
            showNotice("权限已就绪")
        } else {
            textInserter.openAccessibilitySettings()
            showNotice("请授权辅助功能")
        }
    }

    @objc private func resetPanelPosition() {
        let size = panel.frame.size
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = NSPoint(x: visibleFrame.maxX - size.width - 36, y: visibleFrame.midY - size.height / 2)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    private func setPanelSize(_ panelSize: ZenTapPanelSize) {
        selectedPanelSize = panelSize
        resizePanel(to: currentWindowSize())
        showNotice(panelSize.noticeTitle)
    }

    private func setVisualMode(_ visualMode: ZenTapVisualMode) {
        selectedVisualMode = visualMode
        zenView.visualMode = visualMode
        resizePanel(to: currentWindowSize())
        if visualMode == .standard {
            showNotice("标准模式")
        }
    }

    private func currentWindowSize() -> NSSize {
        selectedVisualMode == .zen ? selectedPanelSize.zenWindowSize : selectedPanelSize.windowSize
    }

    private func resizePanel(to newSize: NSSize) {
        let oldFrame = panel.frame
        var origin = NSPoint(x: oldFrame.midX - newSize.width / 2, y: oldFrame.midY - newSize.height / 2)

        let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - newSize.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - newSize.height - 8)

        panel.setFrame(NSRect(origin: origin, size: newSize), display: true)
        zenView.setFrameSize(newSize)
        panel.orderFrontRegardless()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
