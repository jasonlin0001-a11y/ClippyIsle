import SwiftUI
import UIKit
import PencilKit
import Vision
import VisionKit
import UniformTypeIdentifiers
import AVFoundation // 修正 AVMakeRect 錯誤

// MARK: - Custom TextView for EditableTextView
class CustomTextView: UITextView {
    override func paste(_ sender: Any?) { super.paste(sender) }
}

struct EditableTextView: UIViewRepresentable {
    @Binding var item: ClipboardItem
    var highlightedRange: NSRange?
    var fontSize: Double
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var isEditing: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditableTextView
        init(_ parent: EditableTextView) { self.parent = parent }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.isEditing = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.isEditing = false }
        func textViewDidChange(_ textView: UITextView) {
            parent.item.content = textView.text
            if parent.item.type == UTType.rtfd.identifier {
                if let oldFilename = parent.item.filename, let url = parent.clipboardManager.getSharedContainerURL()?.appendingPathComponent(oldFilename) {
                    try? FileManager.default.removeItem(at: url)
                }
                parent.item.type = UTType.text.identifier; parent.item.filename = nil
            }
        }
    }

    func makeUIView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true; textView.isSelectable = true
        textView.font = .systemFont(ofSize: CGFloat(fontSize))
        textView.backgroundColor = .clear
        textView.allowsEditingTextAttributes = false
        textView.autocorrectionType = .no; textView.spellCheckingType = .no
        textView.dataDetectorTypes = .link
        
        let toolbar = UIToolbar(); toolbar.sizeToFit()
        let undoButton = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: textView.undoManager, action: #selector(UndoManager.undo))
        let redoButton = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: textView.undoManager, action: #selector(UndoManager.redo))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textView, action: #selector(UIView.resignFirstResponder))
        toolbar.setItems([undoButton, redoButton, flexibleSpace, doneButton], animated: false)
        textView.inputAccessoryView = toolbar
        
        textView.textColor = textView.traitCollection.userInterfaceStyle == .light ? .darkGray : .label
        updateContent(for: textView)
        return textView
    }

    func updateUIView(_ uiView: CustomTextView, context: Context) {
        uiView.font = .systemFont(ofSize: CGFloat(fontSize))
        if !uiView.isFirstResponder { updateContent(for: uiView) }
        let textStorage = uiView.textStorage
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        
        if let newRange = highlightedRange {
            let safeRange = NSIntersectionRange(fullRange, newRange)
            textStorage.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.5), range: safeRange)
            if !uiView.isFirstResponder {
                let layoutManager = uiView.layoutManager
                let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
                let rectForGlyphRange = layoutManager.boundingRect(forGlyphRange: glyphRange, in: layoutManager.textContainers[0])
                var visibleRect = uiView.bounds; visibleRect = visibleRect.inset(by: uiView.contentInset)
                visibleRect.size.height -= uiView.safeAreaInsets.top + uiView.safeAreaInsets.bottom
                if !visibleRect.contains(rectForGlyphRange) { uiView.scrollRangeToVisible(safeRange) }
            }
        }
    }

    private func updateContent(for textView: CustomTextView) {
        if textView.text != item.content { textView.text = item.content }
        textView.font = .systemFont(ofSize: CGFloat(fontSize))
        textView.textColor = textView.traitCollection.userInterfaceStyle == .light ? .darkGray : .label
    }
}

struct PlainTextEditorView: UIViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var fontSize: Double

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: CGFloat(fontSize))
        textView.backgroundColor = UIColor.systemGray6
        
        let toolbar = UIToolbar(); toolbar.sizeToFit()
        let undoButton = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: textView.undoManager, action: #selector(UndoManager.undo))
        let redoButton = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: textView.undoManager, action: #selector(UndoManager.redo))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textView, action: #selector(UIView.resignFirstResponder))
        toolbar.setItems([undoButton, redoButton, flexibleSpace, doneButton], animated: false)
        textView.inputAccessoryView = toolbar
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        if uiView.font?.pointSize != CGFloat(fontSize) { uiView.font = .systemFont(ofSize: CGFloat(fontSize)) }
        DispatchQueue.main.async {
            if isFocused && !uiView.isFirstResponder { uiView.becomeFirstResponder() }
            else if !isFocused && uiView.isFirstResponder { uiView.resignFirstResponder() }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: PlainTextEditorView
        init(_ parent: PlainTextEditorView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.isFocused = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.isFocused = false }
    }
}

// MARK: - Zoomable & Markup Views (For Image Editing)
struct ZoomableLiveTextScrollView: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableLiveTextScrollView
        var imageView: UIImageView?
        let analyzer = ImageAnalyzer()
        let interaction = ImageAnalysisInteraction()
        init(_ parent: ZoomableLiveTextScrollView) { self.parent = parent }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { return imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
        }
        func analyzeImage(_ image: UIImage) {
            Task {
                let config = ImageAnalyzer.Configuration([.text])
                do {
                    let analysis = try await analyzer.analyze(image, configuration: config)
                    await MainActor.run { interaction.analysis = analysis; interaction.preferredInteractionTypes = .textSelection }
                } catch { print("Live Text analysis failed: \(error)") }
            }
        }
    }
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0; scrollView.minimumZoomScale = 1.0; scrollView.bouncesZoom = true
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit; imageView.isUserInteractionEnabled = true; imageView.addInteraction(context.coordinator.interaction)
        scrollView.addSubview(imageView); imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        context.coordinator.imageView = imageView
        context.coordinator.analyzeImage(image)
        return scrollView
    }
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
}

struct TextAnnotation: Identifiable { let id = UUID(); var text: String; var location: CGPoint; var color: UIColor }

struct ZoomableMarkupView: UIViewRepresentable {
    let image: UIImage
    @Binding var canvasView: PKCanvasView?
    @Binding var undoManager: UndoManager?
    @Binding var textAnnotations: [TextAnnotation]
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableMarkupView
        var containerView: UIView?
        var toolPicker: PKToolPicker?
        var textOverlayView: UIView?
        init(_ parent: ZoomableMarkupView) { self.parent = parent; self.toolPicker = PKToolPicker() }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { return containerView }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0; scrollView.maximumZoomScale = 4.0; scrollView.bouncesZoom = true
        scrollView.backgroundColor = .secondarySystemBackground
        let containerView = UIView()
        scrollView.addSubview(containerView); containerView.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.containerView = containerView
        let imageView = UIImageView(image: image); imageView.contentMode = .scaleAspectFit; imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        let canvas = PKCanvasView(); canvas.drawingPolicy = .anyInput; canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(canvas)
        let textOverlay = UIView(); textOverlay.backgroundColor = .clear; textOverlay.isUserInteractionEnabled = false; textOverlay.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textOverlay); context.coordinator.textOverlayView = textOverlay
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor), imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor), imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: containerView.topAnchor), canvas.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: containerView.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textOverlay.topAnchor.constraint(equalTo: containerView.topAnchor), textOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            textOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor), textOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
        DispatchQueue.main.async {
            self.canvasView = canvas; self.undoManager = canvas.undoManager
            if let toolPicker = context.coordinator.toolPicker { toolPicker.setVisible(true, forFirstResponder: canvas); toolPicker.addObserver(canvas); canvas.becomeFirstResponder() }
        }
        return scrollView
    }
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let textOverlay = context.coordinator.textOverlayView else { return }
        textOverlay.subviews.forEach { $0.removeFromSuperview() }
        for (index, annotation) in textAnnotations.enumerated() {
            let textView = DraggableTextView(text: annotation.text, color: annotation.color)
            textView.frame = CGRect(x: annotation.location.x, y: annotation.location.y, width: 200, height: 50)
            textView.onDragEnd = { newCenter in DispatchQueue.main.async { if index < self.textAnnotations.count { self.textAnnotations[index].location = newCenter } } }
            textView.onTextChange = { newText in DispatchQueue.main.async { if index < self.textAnnotations.count { self.textAnnotations[index].text = newText } } }
            textOverlay.addSubview(textView); textView.isUserInteractionEnabled = true
        }
    }
}

class DraggableTextView: UIView, UITextViewDelegate {
    private let textView = UITextView()
    var onDragEnd: ((CGPoint) -> Void)?
    var onTextChange: ((String) -> Void)?
    init(text: String, color: UIColor) { super.init(frame: .zero); setup(text: text, color: color) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func setup(text: String, color: UIColor) {
        backgroundColor = UIColor.black.withAlphaComponent(0.3); layer.cornerRadius = 8
        textView.text = text; textView.textColor = color; textView.font = .boldSystemFont(ofSize: 20); textView.backgroundColor = .clear; textView.isScrollEnabled = false; textView.delegate = self
        addSubview(textView); textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 5), textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5), textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 50), heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan)); addGestureRecognizer(pan)
    }
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
        if gesture.state == .ended { onDragEnd?(center) }
    }
    func textViewDidChange(_ textView: UITextView) { onTextChange?(textView.text) }
}

struct ImageMerger {
    static func merge(canvas: PKCanvasView, originalImage: UIImage, textAnnotations: [TextAnnotation], canvasBounds: CGRect) -> UIImage {
        // 下面這行需要 AVFoundation
        let imageRenderRect = AVMakeRect(aspectRatio: originalImage.size, insideRect: canvasBounds)
        guard imageRenderRect.width > 0, imageRenderRect.height > 0 else { return originalImage }
        let scale = originalImage.size.width / imageRenderRect.width
        let format = UIGraphicsImageRendererFormat(); format.scale = originalImage.scale
        let renderer = UIGraphicsImageRenderer(size: originalImage.size, format: format)
        return renderer.image { ctx in
            originalImage.draw(at: .zero)
            let drawingImage = canvas.drawing.image(from: imageRenderRect, scale: scale)
            drawingImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
            for annotation in textAnnotations {
                let relativeX = annotation.location.x - imageRenderRect.minX; let relativeY = annotation.location.y - imageRenderRect.minY
                let scaledX = relativeX * scale; let scaledY = relativeY * scale
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 20 * scale), .foregroundColor: annotation.color]
                let str = NSAttributedString(string: annotation.text, attributes: attrs)
                str.draw(at: CGPoint(x: scaledX, y: scaledY))
            }
        }
    }
}

struct FullScreenImageEditor: View {
    @Binding var image: UIImage?
    var onSave: (UIImage) -> Void
    var onCancel: () -> Void
    @State private var canvasView: PKCanvasView?
    @State private var undoManager: UndoManager?
    @State private var textAnnotations: [TextAnnotation] = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onCancel() }
                Spacer()
                Button(action: { addText() }) { Label("Add Text", systemImage: "textformat").labelStyle(.iconOnly).font(.title2) }.padding(.horizontal)
                Spacer()
                Button("Done") {
                    if let canvas = canvasView, let img = image {
                        let newImage = ImageMerger.merge(canvas: canvas, originalImage: img, textAnnotations: textAnnotations, canvasBounds: canvas.bounds)
                        onSave(newImage)
                    } else { onCancel() }
                }.fontWeight(.bold)
            }.padding().background(Color(UIColor.systemBackground))
            if let img = image {
                ZStack {
                    ZoomableMarkupView(image: img, canvasView: $canvasView, undoManager: $undoManager, textAnnotations: $textAnnotations)
                        .background(Color.black)
                        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            } else { Spacer(); ProgressView(); Spacer() }
            HStack(spacing: 40) {
                Button(action: { undoManager?.undo() }) { Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 30)) }.disabled(!(undoManager?.canUndo ?? false))
                Button(action: { undoManager?.redo() }) { Image(systemName: "arrow.uturn.forward.circle.fill").font(.system(size: 30)) }.disabled(!(undoManager?.canRedo ?? false))
            }.padding().frame(maxWidth: .infinity).background(Color(UIColor.systemBackground))
        }.preferredColorScheme(.dark)
    }
    private func addText() { let newAnnotation = TextAnnotation(text: "Text", location: CGPoint(x: 200, y: 300), color: .white); textAnnotations.append(newAnnotation) }
}

struct ImagePreviewEditor: View {
    @Binding var draftItem: ClipboardItem
    @Binding var originalItem: ClipboardItem
    let clipboardManager: ClipboardManager
    @Binding var fontSize: Double
    @State private var currentImage: UIImage?
    @State private var isAnalyzing: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isShowingFullEditor = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    if let image = currentImage {
                        ZStack { ZoomableLiveTextScrollView(image: image) }.frame(height: geometry.size.height * 0.6).background(Color(UIColor.systemGray6))
                    } else { ProgressView().frame(height: geometry.size.height * 0.6) }
                    HStack(spacing: 20) {
                        Button { analyzeText() } label: { Label("Extract All Text", systemImage: "text.viewfinder") }.buttonStyle(.bordered).disabled(isAnalyzing)
                        Button { isShowingFullEditor = true } label: { Label("Markup", systemImage: "pencil.tip.crop.circle") }.buttonStyle(.bordered)
                    }.padding(.vertical, 10)
                    PlainTextEditorView(text: $draftItem.content, isFocused: $isTextFieldFocused, fontSize: fontSize)
                        .frame(minHeight: geometry.size.height * 0.4, alignment: .bottom).cornerRadius(10).padding(.horizontal).padding(.bottom, 10)
                }
            }.ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear { loadImage() }
        .fullScreenCover(isPresented: $isShowingFullEditor) {
            FullScreenImageEditor(image: $currentImage, onSave: { newImage in
                self.currentImage = newImage
                if let data = newImage.pngData() {
                    if let newFilename = clipboardManager.saveFileDataToAppGroup(data: data, type: UTType.png.identifier) {
                        draftItem.filename = newFilename; originalItem.filename = newFilename; originalItem.fileData = nil
                        clipboardManager.updateAndSync(item: originalItem)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {}
                    }
                }
                isShowingFullEditor = false
            }, onCancel: { isShowingFullEditor = false })
        }
    }
    private func loadImage() { if let filename = draftItem.filename, let data = clipboardManager.loadFileData(filename: filename), let uiImage = UIImage(data: data) { self.currentImage = uiImage } }
    private func analyzeText() {
        guard let uiImage = currentImage, let cgImage = uiImage.cgImage else { return }
        isAnalyzing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { (request, error) in
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else { return }
                    let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                    if !recognizedText.isEmpty { let prefix = draftItem.content.isEmpty ? "" : "\n\n"; draftItem.content.append("\(prefix)\(recognizedText)") }
                }
            }
            request.recognitionLanguages = ["zh-Hant", "en-US"]; request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
}