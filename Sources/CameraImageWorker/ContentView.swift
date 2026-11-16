import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct PreviewRequest: Hashable {
    let revision: Int
    let source: URL
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let whiteBalanceTemperatureShift: Double
    let whiteBalanceTint: Double
    let aiDenoiseStrength: AIDenoiseStrength
    let rotationDegrees: Double
    let lens: LensProfile
}

struct ContentView: View {
    @State private var items: [BatchItem] = []
    @State private var selectedSource: URL?
    @State private var selectedForExport: Set<URL> = []
    @State private var editMode = EditApplicationMode.allFiles
    @State private var globalSettings = DevelopSettings.defaultSettings
    @State private var settingsBySource: [URL: DevelopSettings] = [:]
    @State private var inputFolder: URL?
    @State private var outputFolder: URL?
    @State private var selectedLensID = LensProfile.sony11mmF18.id
    @State private var customFocalLength = 11.0
    @State private var customAperture = 1.8
    @State private var customCorrection = 0.1
    @State private var exposure = 0.0
    @State private var contrast = 1.05
    @State private var saturation = 1.0
    @State private var whiteBalanceTemperatureShift = 0.0
    @State private var whiteBalanceTint = 0.0
    @State private var aiDenoiseStrength = AIDenoiseStrength.off
    @State private var rotationDegrees = 0.0
    @State private var jpegQuality = 0.92
    @State private var isImporting = false
    @State private var isChoosingInputFolder = false
    @State private var isScanningFolder = false
    @State private var importError: String?
    @State private var isProcessing = false
    @State private var isSavingCurrent = false
    @State private var editSaveMessage = "편집 내용은 사진 폴더에 자동 저장됩니다"
    @State private var previewImage: NSImage?
    @State private var previewRevision = 0
    @State private var previewError: String?
    @State private var isLoadingPreview = false

    private let processor = RawProcessor()

    var body: some View {
        NavigationSplitView {
            settingsPanel
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 370)
        } detail: {
            batchPanel
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.rawImage, .image],
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .fileImporter(
            isPresented: $isChoosingInputFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: importFolder
        )
        .alert("폴더를 읽을 수 없습니다", isPresented: importErrorBinding) {
            Button("확인", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "알 수 없는 오류")
        }
        .task(id: previewRequest) {
            await loadPreview()
        }
        .task(id: autoSaveRequest) {
            await autoSaveEdits()
        }
    }

    private var settingsPanel: some View {
        Form {
            Section("편집 적용 방식") {
                Picker("적용 방식", selection: editModeBinding) {
                    ForEach(EditApplicationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("카메라") {
                LabeledContent("모델", value: "Sony ZV-E10")
            }

            Section("렌즈 프로필") {
                Picker("렌즈", selection: $selectedLensID) {
                    ForEach(LensProfile.presets) { lens in
                        Text(lens.name).tag(lens.id)
                    }
                    Text("사용자 지정").tag("custom")
                }

                if selectedLensID == "custom" {
                    LabeledContent("초점거리") {
                        TextField("mm", value: $customFocalLength, format: .number)
                            .frame(width: 90)
                    }
                    LabeledContent("최대 조리개") {
                        TextField("F", value: $customAperture, format: .number)
                            .frame(width: 90)
                    }
                    slider("왜곡 보정", value: $customCorrection, range: -0.2...0.2)
                }
            }

            Section("현상") {
                slider("노출", value: $exposure, range: -2...2)
                slider("대비", value: $contrast, range: 0.7...1.4)
                slider("채도", value: $saturation, range: 0...1.8)
                if selectedSource.map(PhotoDiscovery.isRaw) == true {
                    whiteBalanceControls
                }
                rotationControl
                slider("JPEG 품질", value: $jpegQuality, range: 0.6...1)
            }

            Section("AI 품질 향상") {
                Toggle("로컬 AI 노이즈 제거", isOn: aiDenoiseEnabledBinding)
                if aiDenoiseStrength != .off {
                    Picker("강도", selection: $aiDenoiseStrength) {
                        ForEach(Array(AIDenoiseStrength.allCases.dropFirst())) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    Text("Restormer · 미리보기는 빠른 해상도로 처리하고 JPEG 저장은 원본 크기로 처리합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var batchPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Button("RAW 파일 추가") { isImporting = true }
                Button("사진 폴더 열기") { isChoosingInputFolder = true }
                    .disabled(isScanningFolder)
                if isScanningFolder {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("저장 폴더 선택", action: chooseOutputFolder)
                    .disabled(inputFolder == nil || isProcessing)
                Button(isSavingCurrent ? "저장 중…" : "현재 사진 저장", action: saveCurrentPhoto)
                    .disabled(selectedSource == nil || inputFolder == nil || isProcessing || isSavingCurrent)
                Button("전체 선택") {
                    selectedForExport = Set(items.map(\.source))
                }
                .disabled(items.isEmpty || isProcessing)
                Button("선택 해제") {
                    selectedForExport.removeAll()
                }
                .disabled(selectedForExport.isEmpty || isProcessing)
                Spacer()
                Button("\(selectedForExport.count)개 JPEG 변환", action: processAll)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedForExport.isEmpty || outputFolder == nil || isProcessing)
            }
            .padding()

            Divider()

            if items.isEmpty {
                ContentUnavailableView(
                    "RAW 파일을 추가하세요",
                    systemImage: "camera.aperture",
                    description: Text("Sony ARW 파일을 선택하면 원본을 보존한 채 JPEG로 변환합니다.")
                )
            } else {
                HSplitView {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 130, maximum: 190), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(items) { item in
                                ThumbnailCard(
                                    item: item,
                                    isPreviewed: selectedSource == item.source,
                                    isIncluded: selectedForExport.contains(item.source),
                                    onPreview: { selectSource(item.source) },
                                    onToggleIncluded: { toggleExportSelection(item.source) }
                                )
                            }
                        }
                        .padding(12)
                    }
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: 520)

                    previewPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(outputFolder?.path(percentEncoded: false) ?? "저장 폴더를 선택하지 않았습니다")
                        .lineLimit(1)
                    Text(editSaveMessage)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Text("선택 \(selectedForExport.count) / 전체 \(items.count)개")
                    .font(.caption)
            }
            .padding(10)
        }
    }

    private var previewPanel: some View {
        ZStack {
            Color.black.opacity(0.92)

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else if isLoadingPreview {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("RAW 미리보기를 만드는 중…")
                }
                .foregroundStyle(.white)
            } else if let previewError {
                ContentUnavailableView(
                    "미리보기를 표시할 수 없습니다",
                    systemImage: "exclamationmark.triangle",
                    description: Text(previewError)
                )
                .foregroundStyle(.white)
            } else {
                ContentUnavailableView(
                    "사진을 선택하세요",
                    systemImage: "photo",
                    description: Text("왼쪽 갤러리에서 RAW 사진을 선택하면 보정 결과가 표시됩니다.")
                )
                .foregroundStyle(.white)
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private var rotationControl: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("수평 회전")
                Spacer()
                Text("\(rotationDegrees.formatted(.number.precision(.fractionLength(1))))°")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("초기화") { rotationDegrees = 0 }
                    .buttonStyle(.borderless)
                    .disabled(abs(rotationDegrees) < 0.01)
            }
            Slider(value: $rotationDegrees, in: -10...10, step: 0.1)
        }
    }

    private var whiteBalanceControls: some View {
        Group {
            VStack(alignment: .leading) {
                HStack {
                    Text("색온도 보정")
                    Spacer()
                    Text("\(whiteBalanceTemperatureShift.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always()))) K")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $whiteBalanceTemperatureShift, in: -3_000...3_000, step: 50)
            }
            slider("틴트", value: $whiteBalanceTint, range: -100...100)
            Button("화이트밸런스 촬영값으로 복원") {
                whiteBalanceTemperatureShift = 0
                whiteBalanceTint = 0
            }
            .disabled(abs(whiteBalanceTemperatureShift) < 1 && abs(whiteBalanceTint) < 0.01)
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        inputFolder = urls.first?.deletingLastPathComponent()
        addFiles(urls)
    }

    private func importFolder(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let folder = urls.first else { return }
        inputFolder = folder
        isScanningFolder = true

        Task {
            do {
                let discovered = try await Task.detached {
                    try PhotoDiscovery.files(in: folder)
                }.value
                replaceFiles(discovered)
            } catch {
                importError = error.localizedDescription
            }
            isScanningFolder = false
        }
    }

    private func addFiles(_ urls: [URL]) {
        let supported = urls.filter {
            PhotoDiscovery.supportedExtensions.contains($0.pathExtension.lowercased())
        }
        items = Array(Set(items.map(\.source)).union(supported))
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { BatchItem(id: $0, source: $0) }
        selectedForExport.formUnion(supported)
        if selectedSource == nil, let first = items.first?.source {
            selectSource(first)
        }
    }

    private func replaceFiles(_ urls: [URL]) {
        items = urls
            .filter { PhotoDiscovery.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map { BatchItem(id: $0, source: $0) }
        restoreSavedEdits()
        previewRevision += 1
        previewImage = nil
        previewError = nil
    }

    private func restoreSavedEdits() {
        guard let inputFolder else { return }
        let filesByRelativePath = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            EditStore.relativePath(for: item.source, in: inputFolder).map { ($0, item.source) }
        })

        do {
            guard let saved = try EditStore.load(from: inputFolder) else {
                editMode = .allFiles
                globalSettings = .defaultSettings
                settingsBySource.removeAll()
                selectedForExport = Set(items.map(\.source))
                selectedSource = items.first?.source
                applySettings(.defaultSettings)
                editSaveMessage = "편집 내용은 사진 폴더에 자동 저장됩니다"
                return
            }

            editMode = saved.editMode
            globalSettings = saved.globalSettings
            settingsBySource = Dictionary(uniqueKeysWithValues: saved.settingsByRelativePath.compactMap {
                relativePath, settings in
                filesByRelativePath[relativePath].map { ($0, settings) }
            })
            selectedForExport = Set(saved.selectedRelativePaths.compactMap { filesByRelativePath[$0] })
            selectedSource = saved.previewedRelativePath.flatMap { filesByRelativePath[$0] }
                ?? items.first?.source
            switch editMode {
            case .allFiles:
                applySettings(globalSettings)
            case .individual:
                applySettings(selectedSource.flatMap { settingsBySource[$0] } ?? .defaultSettings)
            }
            editSaveMessage = "저장된 편집 내용을 복원했습니다"
        } catch {
            editMode = .allFiles
            globalSettings = .defaultSettings
            settingsBySource.removeAll()
            selectedForExport = Set(items.map(\.source))
            selectedSource = items.first?.source
            applySettings(.defaultSettings)
            editSaveMessage = "저장된 편집 내용을 읽지 못했습니다"
        }
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    private func chooseOutputFolder() {
        guard let inputFolder else { return }
        let panel = NSOpenPanel()
        panel.title = "JPEG 저장 폴더 선택"
        panel.message = "현재 사진 폴더 안에서 기존 폴더를 선택하거나 새로운 폴더를 만드세요."
        panel.prompt = "선택"
        panel.directoryURL = inputFolder
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let folder = panel.url else { return }
            outputFolder = folder
        }
    }

    private func processAll() {
        guard let outputFolder else { return }
        if editMode == .individual {
            persistSelectedSettings()
        } else {
            globalSettings = currentSettings
        }
        isProcessing = true
        let mode = editMode
        let sharedSettings = currentSettings
        let individualSettings = settingsBySource

        Task {
            for index in items.indices where selectedForExport.contains(items[index].source) {
                items[index].state = .processing
                let source = items[index].source
                let settings: DevelopSettings
                switch mode {
                case .allFiles:
                    settings = sharedSettings
                case .individual:
                    settings = individualSettings[source] ?? .defaultSettings
                }
                do {
                    let output = try await processor.develop(
                        source: source,
                        destinationFolder: outputFolder,
                        settings: settings
                    )
                    items[index].state = .completed(output)
                } catch {
                    items[index].state = .failed(error.localizedDescription)
                }
            }
            isProcessing = false
        }
    }

    private func saveCurrentPhoto() {
        guard
            let source = selectedSource,
            let destinationFolder = outputFolder ?? inputFolder
        else { return }
        if editMode == .individual {
            persistSelectedSettings()
        } else {
            globalSettings = currentSettings
        }
        let settings = currentSettings
        isSavingCurrent = true

        Task {
            do {
                let output = try await processor.saveEdited(
                    source: source,
                    destinationFolder: destinationFolder,
                    settings: settings
                )
                editSaveMessage = "\(output.lastPathComponent) 저장 완료"
            } catch {
                editSaveMessage = "현재 사진 저장 실패: \(error.localizedDescription)"
            }
            isSavingCurrent = false
        }
    }

    private func toggleExportSelection(_ source: URL) {
        if selectedForExport.contains(source) {
            selectedForExport.remove(source)
        } else {
            selectedForExport.insert(source)
        }
    }

    private func selectSource(_ source: URL) {
        guard selectedSource != source else { return }
        if editMode == .individual {
            persistSelectedSettings()
        }
        selectedSource = source
        if editMode == .individual {
            applySettings(settingsBySource[source] ?? .defaultSettings)
        }
    }

    private func switchEditMode(to newMode: EditApplicationMode) {
        guard editMode != newMode else { return }
        switch editMode {
        case .allFiles:
            globalSettings = currentSettings
        case .individual:
            persistSelectedSettings()
        }

        editMode = newMode
        switch newMode {
        case .allFiles:
            applySettings(globalSettings)
        case .individual:
            applySettings(selectedSource.flatMap { settingsBySource[$0] } ?? .defaultSettings)
        }
    }

    private func persistSelectedSettings() {
        guard let selectedSource else { return }
        settingsBySource[selectedSource] = currentSettings
    }

    private func applySettings(_ settings: DevelopSettings) {
        exposure = settings.exposure
        contrast = settings.contrast
        saturation = settings.saturation
        whiteBalanceTemperatureShift = settings.whiteBalanceTemperatureShift
        whiteBalanceTint = settings.whiteBalanceTint
        aiDenoiseStrength = settings.aiDenoiseStrength
        rotationDegrees = settings.rotationDegrees
        jpegQuality = settings.jpegQuality

        if LensProfile.presets.contains(where: { $0.id == settings.lens.id }) {
            selectedLensID = settings.lens.id
        } else {
            selectedLensID = "custom"
            customFocalLength = settings.lens.focalLength
            customAperture = settings.lens.aperture
            customCorrection = settings.lens.distortionCorrection
        }
    }

    private var editModeBinding: Binding<EditApplicationMode> {
        Binding(
            get: { editMode },
            set: switchEditMode
        )
    }

    private var aiDenoiseEnabledBinding: Binding<Bool> {
        Binding(
            get: { aiDenoiseStrength != .off },
            set: { aiDenoiseStrength = $0 ? .medium : .off }
        )
    }

    private var autoSaveRequest: AutoSaveRequest? {
        guard let inputFolder, !isScanningFolder, !items.isEmpty else { return nil }
        var effectiveIndividualSettings = settingsBySource
        if editMode == .individual, let selectedSource {
            effectiveIndividualSettings[selectedSource] = currentSettings
        }
        let relativeSettings = Dictionary(uniqueKeysWithValues: effectiveIndividualSettings.compactMap {
            source, settings in
            EditStore.relativePath(for: source, in: inputFolder).map { ($0, settings) }
        })
        let selectedPaths = Set(selectedForExport.compactMap {
            EditStore.relativePath(for: $0, in: inputFolder)
        })
        let document = SavedEditDocument(
            editMode: editMode,
            globalSettings: editMode == .allFiles ? currentSettings : globalSettings,
            settingsByRelativePath: relativeSettings,
            selectedRelativePaths: selectedPaths,
            previewedRelativePath: selectedSource.flatMap {
                EditStore.relativePath(for: $0, in: inputFolder)
            }
        )
        return AutoSaveRequest(folder: inputFolder, document: document)
    }

    @MainActor
    private func autoSaveEdits() async {
        guard let request = autoSaveRequest else { return }
        do {
            try await Task.sleep(for: .milliseconds(450))
            try Task.checkCancellation()
            try await Task.detached {
                try EditStore.save(request.document, in: request.folder)
            }.value
            editSaveMessage = "편집 내용 자동 저장됨"
        } catch is CancellationError {
            return
        } catch {
            editSaveMessage = "편집 내용 자동 저장 실패"
        }
    }

    @MainActor
    private func loadPreview() async {
        guard let previewRequest else {
            previewImage = nil
            previewError = nil
            return
        }

        isLoadingPreview = true
        previewError = nil
        do {
            try await Task.sleep(for: .milliseconds(120))
            let data = try await processor.previewJPEGData(
                source: previewRequest.source,
                settings: currentSettings
            )
            try Task.checkCancellation()
            previewImage = NSImage(data: data)
            isLoadingPreview = false
        } catch is CancellationError {
            return
        } catch {
            previewImage = nil
            previewError = error.localizedDescription
            isLoadingPreview = false
        }
    }

    private var previewRequest: PreviewRequest? {
        guard let selectedSource else { return nil }
        return PreviewRequest(
            revision: previewRevision,
            source: selectedSource,
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            whiteBalanceTemperatureShift: whiteBalanceTemperatureShift,
            whiteBalanceTint: whiteBalanceTint,
            aiDenoiseStrength: aiDenoiseStrength,
            rotationDegrees: rotationDegrees,
            lens: selectedLens
        )
    }

    private var currentSettings: DevelopSettings {
        DevelopSettings(
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            whiteBalanceTemperatureShift: whiteBalanceTemperatureShift,
            whiteBalanceTint: whiteBalanceTint,
            aiDenoiseStrength: aiDenoiseStrength,
            rotationDegrees: rotationDegrees,
            jpegQuality: jpegQuality,
            lens: selectedLens
        )
    }

    private var selectedLens: LensProfile {
        if selectedLensID == "custom" {
            return .custom(
                focalLength: customFocalLength,
                aperture: customAperture,
                correction: customCorrection
            )
        }
        return LensProfile.presets.first { $0.id == selectedLensID } ?? .sony11mmF18
    }
}
