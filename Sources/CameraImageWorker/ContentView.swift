import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsPanelMode: String, CaseIterable, Identifiable {
    case automatic
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic:
            localized("자동 설정(필터)")
        case .advanced:
            localized("고급 설정")
        }
    }
}

private enum AutomaticFilter: String, CaseIterable, Identifiable {
    case original
    case natural
    case vividTravel
    case warmFilm
    case night
    case portrait

    var id: Self { self }

    var title: String {
        switch self {
        case .original: localized("원본")
        case .natural: localized("자연스럽게")
        case .vividTravel: localized("선명한 여행")
        case .warmFilm: localized("따뜻한 필름")
        case .night: localized("야간 개선")
        case .portrait: localized("인물 보정")
        }
    }

    var subtitle: String {
        switch self {
        case .original: localized("효과를 초기화합니다")
        case .natural: localized("밝기와 암부를 자연스럽게")
        case .vividTravel: localized("색과 풍경을 또렷하게")
        case .warmFilm: localized("따뜻한 색과 필름 입자")
        case .night: localized("어두운 사진과 노이즈 개선")
        case .portrait: localized("피부와 얼굴 디테일 보정")
        }
    }

    var symbol: String {
        switch self {
        case .original: "arrow.counterclockwise"
        case .natural: "leaf"
        case .vividTravel: "sun.max"
        case .warmFilm: "film"
        case .night: "moon.stars"
        case .portrait: "person.crop.circle"
        }
    }
}

private struct PreviewRequest: Hashable {
    let revision: Int
    let source: URL
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let highlights: Double
    let shadows: Double
    let whites: Double
    let blacks: Double
    let vignetteAmount: Double
    let vignetteMidpoint: Double
    let vignetteFeather: Double
    let grainAmount: Double
    let grainSize: Double
    let grainRoughness: Double
    let perspectiveVertical: Double
    let perspectiveHorizontal: Double
    let whiteBalanceTemperatureShift: Double
    let whiteBalanceTint: Double
    let aiDenoiseStrength: AIDenoiseStrength
    let shakeCorrectionStrength: ShakeCorrectionStrength
    let faceRestorationStrength: FaceRestorationStrength
    let faceRegion: NormalizedRegion?
    let rotationDegrees: Double
    let cropAspect: CropAspect
    let cropCustomRatio: Double
    let cropZoom: Double
    let cropOffsetX: Double
    let cropOffsetY: Double
    let lens: LensProfile
}

struct ContentView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system
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
    @State private var highlights = 0.0
    @State private var shadows = 0.0
    @State private var whites = 0.0
    @State private var blacks = 0.0
    @State private var vignetteAmount = 0.0
    @State private var vignetteMidpoint = 0.5
    @State private var vignetteFeather = 0.5
    @State private var grainAmount = 0.0
    @State private var grainSize = 1.0
    @State private var grainRoughness = 0.5
    @State private var perspectiveVertical = 0.0
    @State private var perspectiveHorizontal = 0.0
    @State private var whiteBalanceTemperatureShift = 0.0
    @State private var whiteBalanceTint = 0.0
    @State private var aiDenoiseStrength = AIDenoiseStrength.off
    @State private var shakeCorrectionStrength = ShakeCorrectionStrength.off
    @State private var faceRestorationStrength = FaceRestorationStrength.off
    @State private var faceRegion: NormalizedRegion?
    @State private var isSelectingFaceRegion = false
    @State private var faceDragStart: CGPoint?
    @State private var faceDraftRect: CGRect?
    @State private var rotationDegrees = 0.0
    @State private var cropAspect = CropAspect.original
    @State private var cropCustomRatio = 1.0
    @State private var cropZoom = 1.0
    @State private var cropOffsetX = 0.0
    @State private var cropOffsetY = 0.0
    @State private var jpegQuality = 0.92
    @State private var isImporting = false
    @State private var isChoosingInputFolder = false
    @State private var isScanningFolder = false
    @State private var importError: String?
    @State private var isProcessing = false
    @State private var processingCompletedCount = 0
    @State private var processingTotalCount = 0
    @State private var isSavingCurrent = false
    @State private var editSaveMessage = localized("편집 내용은 사진 폴더에 자동 저장됩니다")
    @State private var previewImage: NSImage?
    @State private var histogramData = HistogramData.empty
    @State private var previewZoom = 1.0
    @State private var previewPan = CGSize.zero
    @State private var previewPanStart: CGPoint?
    @State private var previewPanInitialOffset = CGSize.zero
    @State private var isPreviewPanning = false
    @State private var previewRevision = 0
    @State private var previewError: String?
    @State private var isLoadingPreview = false
    @State private var selectedMetadata: PhotoMetadata?
    @State private var isAIOptionsExpanded = false
    @State private var isEffectsExpanded = false
    @State private var settingsPanelMode = SettingsPanelMode.automatic
    @State private var selectedAutomaticFilter: AutomaticFilter?
    @State private var isShowingResetConfirmation = false
    @State private var cropDragStart: CGPoint?
    @State private var cropDraftRect: CGRect?
    @State private var cropMoveInitialRect: CGRect?

    private let processor = RawProcessor()

    var body: some View {
        NavigationSplitView {
            settingsPanel
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 370)
        } detail: {
            batchPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            Text(importError ?? localized("알 수 없는 오류"))
        }
        .task(id: previewRequest) {
            await loadPreview()
        }
        .task(id: autoSaveRequest) {
            await autoSaveEdits()
        }
        .task(id: selectedSource) {
            await loadSelectedMetadata()
        }
        .confirmationDialog(
            editMode == .allFiles ? localized("모든 파일의 설정을 초기화할까요?") : localized("현재 사진의 설정을 초기화할까요?"),
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("설정 초기화", role: .destructive, action: resetCurrentSettings)
            Button("취소", role: .cancel) {}
        } message: {
            Text("원본 사진과 저장된 JPEG 파일은 변경되지 않습니다.")
        }
        .environment(\.locale, appLanguage.locale)
        .onChange(of: appLanguage) {
            editSaveMessage = localized("편집 내용은 사진 폴더에 자동 저장됩니다")
        }
    }

    private var settingsPanel: some View {
        Form {
            Section("앱 언어") {
                Picker("언어", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Picker("설정 화면", selection: $settingsPanelMode) {
                    ForEach(SettingsPanelMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("설정 초기화", systemImage: "arrow.counterclockwise")
                }
            }

            Section("편집 적용 방식") {
                Picker("적용 방식", selection: editModeBinding) {
                    ForEach(EditApplicationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            if settingsPanelMode == .automatic {
                automaticFilterSection
            } else {

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
                HistogramView(data: histogramData)
                slider("노출", value: $exposure, range: -2...2)
                slider("대비", value: $contrast, range: 0.7...1.4)
                signedSlider("하이라이트", value: $highlights)
                signedSlider("섀도", value: $shadows)
                signedSlider("화이트", value: $whites)
                signedSlider("블랙", value: $blacks)
                slider("채도", value: $saturation, range: 0...1.8)
                if selectedSource.map(PhotoDiscovery.isRaw) == true {
                    whiteBalanceControls
                }
                rotationControl
                cropControls
                slider("JPEG 품질", value: $jpegQuality, range: 0.6...1)
            }

            Section {
                DisclosureGroup(isExpanded: $isAIOptionsExpanded) {
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

                    Divider()
                    Toggle("흔들림 보정", isOn: shakeCorrectionEnabledBinding)
                    if shakeCorrectionStrength != .off {
                    Picker("흔들림 보정 강도", selection: $shakeCorrectionStrength) {
                        ForEach(Array(ShakeCorrectionStrength.allCases.dropFirst())) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    Text("가벼운 손떨림과 미세한 흐림을 로컬에서 복원합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Divider()
                    Toggle("얼굴 복원", isOn: faceRestorationEnabledBinding)
                    if faceRestorationStrength != .off {
                    Picker("얼굴 복원 강도", selection: $faceRestorationStrength) {
                        ForEach(Array(FaceRestorationStrength.allCases.dropFirst())) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    Text("얼굴을 자동으로 찾아 피부 노이즈와 눈·윤곽 디테일을 보정합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(isSelectingFaceRegion ? localized("얼굴 영역 지정 중") : localized("얼굴 영역 지정")) {
                            isSelectingFaceRegion.toggle()
                            if isSelectingFaceRegion {
                                isPreviewPanning = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(isSelectingFaceRegion ? .accentColor : .secondary)
                        if faceRegion != nil {
                            Button("자동 찾기") {
                                faceRegion = nil
                                isSelectingFaceRegion = false
                            }
                        }
                    }
                    }

                    if isLoadingPreview, hasActiveAIEnhancement {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("AI 미리보기 처리 중…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    HStack {
                        Label("AI 품질 향상", systemImage: "sparkles")
                        Spacer()
                        if hasActiveAIEnhancement {
                            Text("사용 중")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            Section {
                DisclosureGroup(isExpanded: $isEffectsExpanded) {
                    GroupBox("비네팅") {
                        slider("양", value: $vignetteAmount, range: -1...1)
                        slider("중심점", value: $vignetteMidpoint, range: 0...1)
                        slider("부드러움", value: $vignetteFeather, range: 0...1)
                    }

                    GroupBox("필름 그레인") {
                        slider("양", value: $grainAmount, range: 0...1)
                        slider("크기", value: $grainSize, range: 0.5...3)
                        slider("거칠기", value: $grainRoughness, range: 0...1)
                    }

                    GroupBox("원근 교정") {
                        signedSlider("수직", value: $perspectiveVertical)
                        signedSlider("수평", value: $perspectiveHorizontal)
                        Button("원근 교정 초기화") {
                            perspectiveVertical = 0
                            perspectiveHorizontal = 0
                        }
                        .disabled(abs(perspectiveVertical) < 0.001 && abs(perspectiveHorizontal) < 0.001)
                    }
                } label: {
                    HStack {
                        Label("효과 및 교정", systemImage: "camera.filters")
                        Spacer()
                        if hasActiveEffects {
                            Text("사용 중")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            }
        }
        .formStyle(.grouped)
        .id(appLanguage)
    }

    private var automaticFilterSection: some View {
        Section("사진 스타일") {
            ForEach(AutomaticFilter.allCases) { filter in
                Button {
                    applyAutomaticFilter(filter)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: filter.symbol)
                            .font(.title3)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(filter.title)
                                .foregroundStyle(.primary)
                            Text(filter.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedAutomaticFilter == filter {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }

            Button("고급 설정에서 미세 조정") {
                settingsPanelMode = .advanced
            }
        }
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
                Button(isSavingCurrent ? localized("저장 중…") : localized("현재 사진 저장"), action: saveCurrentPhoto)
                    .disabled(selectedSource == nil || inputFolder == nil || isProcessing || isSavingCurrent)
                if isSavingCurrent {
                    ProgressView()
                        .controlSize(.small)
                    if hasActiveAIEnhancement {
                        Text("AI 처리 중")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("전체 선택") {
                    selectedForExport = Set(items.map(\.source))
                }
                .disabled(items.isEmpty || isProcessing)
                Button("선택 해제") {
                    selectedForExport.removeAll()
                }
                .disabled(selectedForExport.isEmpty || isProcessing)
                Spacer()
                if isProcessing, processingTotalCount > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        ProgressView(
                            value: Double(processingCompletedCount),
                            total: Double(processingTotalCount)
                        )
                        .frame(width: 150)
                        Text(localizedFormat("처리 %d / %d", processingCompletedCount, processingTotalCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(localizedFormat("%d개 JPEG 변환", selectedForExport.count), action: processAll)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Text(outputFolder?.path(percentEncoded: false) ?? localized("저장 폴더를 선택하지 않았습니다"))
                        .lineLimit(1)
                    Text(editSaveMessage)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Text(localizedFormat("선택 %d / 전체 %d개", selectedForExport.count, items.count))
                    .font(.caption)
            }
            .padding(10)
        }
    }

    private var previewPanel: some View {
        ZStack {
            Color.black.opacity(0.92)

            if let previewImage {
                interactivePreview(previewImage)
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
        .overlay(alignment: .topTrailing) {
            if previewImage != nil {
                previewZoomControls
                    .padding(12)
            }
        }
        .clipped()
    }

    private var previewZoomControls: some View {
        HStack(spacing: 8) {
            Button {
                setPreviewZoom(max(1, previewZoom - 0.25))
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(previewZoom <= 1)

            Slider(value: previewZoomBinding, in: 1...4, step: 0.05)
                .frame(width: 110)

            Text("\(previewZoom.formatted(.number.precision(.fractionLength(1))))×")
                .monospacedDigit()
                .frame(width: 34)

            Button {
                setPreviewZoom(min(4, previewZoom + 0.25))
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(previewZoom >= 4)

            Button("맞춤") {
                setPreviewZoom(1)
            }
            .disabled(previewZoom == 1)

            Button {
                isPreviewPanning.toggle()
            } label: {
                Label("이동", systemImage: "hand.draw")
            }
            .disabled(previewZoom <= 1)
            .background(isPreviewPanning ? Color.accentColor.opacity(0.35) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.72), in: Capsule())
        .foregroundStyle(.white)
    }

    private var previewZoomBinding: Binding<Double> {
        Binding(
            get: { previewZoom },
            set: setPreviewZoom
        )
    }

    private func setPreviewZoom(_ zoom: Double) {
        previewZoom = min(4, max(1, zoom))
        if previewZoom <= 1.001 {
            previewPan = .zero
            previewPanInitialOffset = .zero
            isPreviewPanning = false
        } else {
            isPreviewPanning = true
        }
    }

    private func interactivePreview(_ image: NSImage) -> some View {
        GeometryReader { geometry in
            let imageRect = fittedImageRect(
                imageSize: image.size,
                in: geometry.size,
                padding: 24,
                zoom: previewZoom
            )
            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                cropOverlay(in: imageRect, imageSize: image.size)
                faceRegionOverlay(in: imageRect)

                if let selectedMetadata, !selectedMetadata.summaryItems.isEmpty {
                    metadataBar(selectedMetadata)
                        .frame(maxWidth: min(760, geometry.size.width - 32))
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height - 28
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                previewCropDragGesture(
                    in: imageRect,
                    imageSize: image.size,
                    viewportSize: geometry.size
                )
            )
        }
    }

    private func faceRegionOverlay(in imageRect: CGRect) -> some View {
        let localRect: CGRect? = faceDraftRect ?? faceRegion.map {
            CGRect(
                x: $0.x * imageRect.width,
                y: $0.y * imageRect.height,
                width: $0.width * imageRect.width,
                height: $0.height * imageRect.height
            )
        }
        return ZStack(alignment: .topLeading) {
            if let localRect, faceRestorationStrength != .off {
                Rectangle()
                    .stroke(.yellow, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    .background(.yellow.opacity(0.08))
                    .frame(width: localRect.width, height: localRect.height)
                    .offset(x: localRect.minX, y: localRect.minY)
                Text("얼굴")
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.yellow)
                    .offset(x: localRect.minX, y: max(0, localRect.minY - 18))
            }
        }
        .frame(width: imageRect.width, height: imageRect.height, alignment: .topLeading)
        .position(x: imageRect.midX, y: imageRect.midY)
        .allowsHitTesting(false)
    }

    private func metadataBar(_ metadata: PhotoMetadata) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Image(systemName: "camera")
                ForEach(Array(metadata.summaryItems.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                    }
                    Text(item)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.black.opacity(0.72), in: Capsule())
    }

    private func cropOverlay(in imageRect: CGRect, imageSize: CGSize) -> some View {
        let localBounds = CGRect(origin: .zero, size: imageRect.size)
        let selection = cropDraftRect ?? displayedCropRect(in: localBounds, imageSize: imageSize)
        return ZStack(alignment: .topLeading) {
            if isCropAdjusted || cropDraftRect != nil {
                cropMask(imageRect: localBounds, selection: selection)
                Rectangle()
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                    .frame(width: selection.width, height: selection.height)
                    .offset(x: selection.minX, y: selection.minY)
                    .shadow(color: .black, radius: 2)
            }

            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
        }
        .frame(width: imageRect.width, height: imageRect.height)
        .position(x: imageRect.midX, y: imageRect.midY)
        .help("박스 안을 드래그하면 이동하고, 바깥을 드래그하면 새 영역을 지정합니다")
    }

    private func cropMask(imageRect: CGRect, selection: CGRect) -> some View {
        Path { path in
            path.addRect(imageRect)
            path.addRect(selection)
        }
        .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
    }

    private func previewCropDragGesture(
        in imageRect: CGRect,
        imageSize: CGSize,
        viewportSize: CGSize
    ) -> some Gesture {
        let localBounds = CGRect(origin: .zero, size: imageRect.size)
        return DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                if isPreviewPanning, previewZoom > 1 {
                    let start = previewPanStart ?? value.location
                    if previewPanStart == nil {
                        previewPanStart = start
                        previewPanInitialOffset = previewPan
                    }
                    let maximumX = max(0, (imageRect.width - viewportSize.width) / 2 + 24)
                    let maximumY = max(0, (imageRect.height - viewportSize.height) / 2 + 24)
                    previewPan = CGSize(
                        width: min(maximumX, max(-maximumX, previewPanInitialOffset.width + value.location.x - start.x)),
                        height: min(maximumY, max(-maximumY, previewPanInitialOffset.height + value.location.y - start.y))
                    )
                    return
                }
                let canvasPoint = clamped(value.location, to: imageRect)
                let point = CGPoint(
                    x: canvasPoint.x - imageRect.minX,
                    y: canvasPoint.y - imageRect.minY
                )
                if isSelectingFaceRegion {
                    let start = faceDragStart ?? point
                    faceDragStart = start
                    faceDraftRect = standardizedRect(from: start, to: point)
                        .intersection(localBounds)
                    return
                }
                if cropDragStart == nil {
                    let currentRect = displayedCropRect(in: localBounds, imageSize: imageSize)
                    cropDragStart = point
                    if isCropAdjusted, currentRect.contains(point) {
                        cropMoveInitialRect = currentRect
                        cropDraftRect = currentRect
                    } else {
                        cropMoveInitialRect = nil
                    }
                }

                guard let start = cropDragStart else { return }
                if let initialRect = cropMoveInitialRect {
                    cropDraftRect = movedCropRect(
                        initialRect,
                        translation: CGSize(
                            width: point.x - start.x,
                            height: point.y - start.y
                        ),
                        inside: localBounds
                    )
                } else {
                    cropDraftRect = standardizedRect(from: start, to: point)
                        .intersection(localBounds)
                }
            }
            .onEnded { _ in
                if isPreviewPanning {
                    previewPanStart = nil
                    previewPanInitialOffset = previewPan
                    return
                }
                if isSelectingFaceRegion {
                    if let rect = faceDraftRect, rect.width >= 20, rect.height >= 20 {
                        faceRegion = NormalizedRegion(
                            x: rect.minX / localBounds.width,
                            y: rect.minY / localBounds.height,
                            width: rect.width / localBounds.width,
                            height: rect.height / localBounds.height
                        )
                    }
                    faceDragStart = nil
                    faceDraftRect = nil
                    isSelectingFaceRegion = false
                    return
                }
                defer {
                    cropDragStart = nil
                    cropDraftRect = nil
                    cropMoveInitialRect = nil
                }
                guard let rect = cropDraftRect, rect.width >= 20, rect.height >= 20 else { return }
                applyDraggedCrop(rect, imageRect: localBounds, imageSize: imageSize)
            }
    }

    private func fittedImageRect(
        imageSize: CGSize,
        in availableSize: CGSize,
        padding: CGFloat,
        zoom: Double
    ) -> CGRect {
        let usableWidth = max(1, availableSize.width - padding * 2)
        let usableHeight = max(1, availableSize.height - padding * 2)
        let scale = min(usableWidth / imageSize.width, usableHeight / imageSize.height) * CGFloat(zoom)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (availableSize.width - size.width) / 2 + previewPan.width,
            y: (availableSize.height - size.height) / 2 + previewPan.height,
            width: size.width,
            height: size.height
        )
    }

    private func displayedCropRect(in imageRect: CGRect, imageSize: CGSize) -> CGRect {
        let pixelExtent = CGRect(origin: .zero, size: imageSize)
        let pixelRect = RawProcessor.cropRect(
            in: pixelExtent,
            aspect: cropAspect,
            customRatio: cropCustomRatio,
            zoom: cropZoom,
            offsetX: cropOffsetX,
            offsetY: cropOffsetY
        )
        return CGRect(
            x: imageRect.minX + pixelRect.minX / imageSize.width * imageRect.width,
            y: imageRect.minY
                + (imageSize.height - pixelRect.maxY) / imageSize.height * imageRect.height,
            width: pixelRect.width / imageSize.width * imageRect.width,
            height: pixelRect.height / imageSize.height * imageRect.height
        )
    }

    private func applyDraggedCrop(_ rect: CGRect, imageRect: CGRect, imageSize: CGSize) {
        let normalizedX = (rect.minX - imageRect.minX) / imageRect.width
        let normalizedY = (rect.minY - imageRect.minY) / imageRect.height
        let normalizedWidth = rect.width / imageRect.width
        let normalizedHeight = rect.height / imageRect.height
        let pixelWidth = normalizedWidth * imageSize.width
        let pixelHeight = normalizedHeight * imageSize.height
        let customRatio = pixelWidth / pixelHeight
        let sourceRatio = imageSize.width / imageSize.height

        var baseWidth = imageSize.width
        var baseHeight = imageSize.height
        if sourceRatio > customRatio {
            baseWidth = baseHeight * customRatio
        } else {
            baseHeight = baseWidth / customRatio
        }

        let zoom = min(10, max(1, baseWidth / pixelWidth))
        let actualWidth = baseWidth / zoom
        let actualHeight = baseHeight / zoom
        let centerX = (normalizedX + normalizedWidth / 2) * imageSize.width
        let centerY = (normalizedY + normalizedHeight / 2) * imageSize.height
        let horizontalTravel = max(0, imageSize.width - actualWidth) / 2
        let verticalTravel = max(0, imageSize.height - actualHeight) / 2

        cropAspect = .freeform
        cropCustomRatio = Double(customRatio)
        cropZoom = Double(zoom)
        cropOffsetX = horizontalTravel > 0 ? Double((centerX - imageSize.width / 2) / horizontalTravel) : 0
        cropOffsetY = verticalTravel > 0 ? Double((centerY - imageSize.height / 2) / verticalTravel) : 0
    }

    private func clamped(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(rect.maxX, max(rect.minX, point.x)),
            y: min(rect.maxY, max(rect.minY, point.y))
        )
    }

    private func standardizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func movedCropRect(
        _ rect: CGRect,
        translation: CGSize,
        inside bounds: CGRect
    ) -> CGRect {
        let proposedX = rect.minX + translation.width
        let proposedY = rect.minY + translation.height
        return CGRect(
            x: min(bounds.maxX - rect.width, max(bounds.minX, proposedX)),
            y: min(bounds.maxY - rect.height, max(bounds.minY, proposedY)),
            width: rect.width,
            height: rect.height
        )
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(localized(title))
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func signedSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(localized(title))
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: -1...1)
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

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("크롭")
                Spacer()
                Button("초기화") {
                    cropAspect = .original
                    cropCustomRatio = 1
                    cropZoom = 1
                    cropOffsetX = 0
                    cropOffsetY = 0
                }
                .buttonStyle(.borderless)
                .disabled(!isCropAdjusted)
            }
            Picker("비율", selection: $cropAspect) {
                ForEach(CropAspect.allCases) { aspect in
                    Text(aspect.title).tag(aspect)
                }
            }
            .pickerStyle(.segmented)
            slider("확대", value: $cropZoom, range: 1...10)
            if cropAspect != .original || cropZoom > 1.001 {
                slider("가로 위치", value: $cropOffsetX, range: -1...1)
                slider("세로 위치", value: $cropOffsetY, range: -1...1)
            }
        }
    }

    private var isCropAdjusted: Bool {
        cropAspect != .original
            || abs(cropZoom - 1) > 0.001
            || abs(cropOffsetX) > 0.001
            || abs(cropOffsetY) > 0.001
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
                editSaveMessage = localized("편집 내용은 사진 폴더에 자동 저장됩니다")
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
            editSaveMessage = localized("저장된 편집 내용을 복원했습니다")
        } catch {
            editMode = .allFiles
            globalSettings = .defaultSettings
            settingsBySource.removeAll()
            selectedForExport = Set(items.map(\.source))
            selectedSource = items.first?.source
            applySettings(.defaultSettings)
            editSaveMessage = localized("저장된 편집 내용을 읽지 못했습니다")
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
        panel.title = localized("JPEG 저장 폴더 선택")
        panel.message = localized("현재 사진 폴더 안에서 기존 폴더를 선택하거나 새로운 폴더를 만드세요.")
        panel.prompt = localized("선택")
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
        processingCompletedCount = 0
        processingTotalCount = selectedForExport.count
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
                processingCompletedCount += 1
            }
            isProcessing = false
            processingTotalCount = 0
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
                editSaveMessage = localizedFormat("%@ 저장 완료", output.lastPathComponent)
            } catch {
                editSaveMessage = localizedFormat("현재 사진 저장 실패: %@", error.localizedDescription)
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
        setPreviewZoom(1)
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
        highlights = settings.highlights
        shadows = settings.shadows
        whites = settings.whites
        blacks = settings.blacks
        vignetteAmount = settings.vignetteAmount
        vignetteMidpoint = settings.vignetteMidpoint
        vignetteFeather = settings.vignetteFeather
        grainAmount = settings.grainAmount
        grainSize = settings.grainSize
        grainRoughness = settings.grainRoughness
        perspectiveVertical = settings.perspectiveVertical
        perspectiveHorizontal = settings.perspectiveHorizontal
        whiteBalanceTemperatureShift = settings.whiteBalanceTemperatureShift
        whiteBalanceTint = settings.whiteBalanceTint
        aiDenoiseStrength = settings.aiDenoiseStrength
        shakeCorrectionStrength = settings.shakeCorrectionStrength
        faceRestorationStrength = settings.faceRestorationStrength
        faceRegion = settings.faceRegion
        rotationDegrees = settings.rotationDegrees
        cropAspect = settings.cropAspect
        cropCustomRatio = settings.cropCustomRatio
        cropZoom = settings.cropZoom
        cropOffsetX = settings.cropOffsetX
        cropOffsetY = settings.cropOffsetY
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

    private var shakeCorrectionEnabledBinding: Binding<Bool> {
        Binding(
            get: { shakeCorrectionStrength != .off },
            set: { shakeCorrectionStrength = $0 ? .medium : .off }
        )
    }

    private var faceRestorationEnabledBinding: Binding<Bool> {
        Binding(
            get: { faceRestorationStrength != .off },
            set: { faceRestorationStrength = $0 ? .medium : .off }
        )
    }

    private var hasActiveAIEnhancement: Bool {
        aiDenoiseStrength != .off
            || shakeCorrectionStrength != .off
            || faceRestorationStrength != .off
    }

    private var hasActiveEffects: Bool {
        abs(vignetteAmount) > 0.001
            || grainAmount > 0.001
            || abs(perspectiveVertical) > 0.001
            || abs(perspectiveHorizontal) > 0.001
    }

    private func applyAutomaticFilter(_ filter: AutomaticFilter) {
        exposure = 0
        contrast = 1.05
        saturation = 1
        highlights = 0
        shadows = 0
        whites = 0
        blacks = 0
        whiteBalanceTemperatureShift = 0
        whiteBalanceTint = 0
        vignetteAmount = 0
        vignetteMidpoint = 0.5
        vignetteFeather = 0.5
        grainAmount = 0
        grainSize = 1
        grainRoughness = 0.5
        aiDenoiseStrength = .off
        shakeCorrectionStrength = .off
        faceRestorationStrength = .off
        faceRegion = nil

        switch filter {
        case .original:
            break
        case .natural:
            shadows = 0.16
            highlights = -0.1
            whites = 0.04
            blacks = -0.04
        case .vividTravel:
            contrast = 1.12
            saturation = 1.18
            highlights = -0.16
            shadows = 0.2
            whites = 0.12
            blacks = -0.12
            vignetteAmount = 0.08
        case .warmFilm:
            contrast = 1.08
            saturation = 0.96
            whiteBalanceTemperatureShift = 350
            whiteBalanceTint = 4
            highlights = -0.12
            shadows = 0.12
            blacks = 0.1
            vignetteAmount = 0.2
            grainAmount = 0.24
            grainSize = 1.2
            grainRoughness = 0.55
        case .night:
            exposure = 0.22
            contrast = 1.08
            saturation = 0.95
            highlights = -0.34
            shadows = 0.26
            whites = -0.08
            blacks = -0.08
            aiDenoiseStrength = .medium
        case .portrait:
            contrast = 0.98
            saturation = 1.02
            whiteBalanceTemperatureShift = 150
            highlights = -0.2
            shadows = 0.18
            blacks = 0.04
            faceRestorationStrength = .medium
        }
        selectedAutomaticFilter = filter
    }

    private func resetCurrentSettings() {
        let defaults = DevelopSettings.defaultSettings
        applySettings(defaults)
        selectedAutomaticFilter = nil
        isSelectingFaceRegion = false
        setPreviewZoom(1)

        switch editMode {
        case .allFiles:
            globalSettings = defaults
        case .individual:
            if let selectedSource {
                settingsBySource[selectedSource] = defaults
            }
        }
        editSaveMessage = editMode == .allFiles
            ? localized("모든 파일 설정을 초기화했습니다")
            : localized("현재 사진 설정을 초기화했습니다")
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
            editSaveMessage = localized("편집 내용 자동 저장됨")
        } catch is CancellationError {
            return
        } catch {
            editSaveMessage = localized("편집 내용 자동 저장 실패")
        }
    }

    @MainActor
    private func loadPreview() async {
        guard let previewRequest else {
            previewImage = nil
            histogramData = .empty
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
            let image = NSImage(data: data)
            previewImage = image
            histogramData = image.map(HistogramData.make(from:)) ?? .empty
            isLoadingPreview = false
        } catch is CancellationError {
            return
        } catch {
            previewImage = nil
            histogramData = .empty
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
            highlights: highlights,
            shadows: shadows,
            whites: whites,
            blacks: blacks,
            vignetteAmount: vignetteAmount,
            vignetteMidpoint: vignetteMidpoint,
            vignetteFeather: vignetteFeather,
            grainAmount: grainAmount,
            grainSize: grainSize,
            grainRoughness: grainRoughness,
            perspectiveVertical: perspectiveVertical,
            perspectiveHorizontal: perspectiveHorizontal,
            whiteBalanceTemperatureShift: whiteBalanceTemperatureShift,
            whiteBalanceTint: whiteBalanceTint,
            aiDenoiseStrength: aiDenoiseStrength,
            shakeCorrectionStrength: shakeCorrectionStrength,
            faceRestorationStrength: faceRestorationStrength,
            faceRegion: faceRegion,
            rotationDegrees: rotationDegrees,
            cropAspect: cropAspect,
            cropCustomRatio: cropCustomRatio,
            cropZoom: cropZoom,
            cropOffsetX: cropOffsetX,
            cropOffsetY: cropOffsetY,
            lens: selectedLens
        )
    }

    private var currentSettings: DevelopSettings {
        DevelopSettings(
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            highlights: highlights,
            shadows: shadows,
            whites: whites,
            blacks: blacks,
            vignetteAmount: vignetteAmount,
            vignetteMidpoint: vignetteMidpoint,
            vignetteFeather: vignetteFeather,
            grainAmount: grainAmount,
            grainSize: grainSize,
            grainRoughness: grainRoughness,
            perspectiveVertical: perspectiveVertical,
            perspectiveHorizontal: perspectiveHorizontal,
            whiteBalanceTemperatureShift: whiteBalanceTemperatureShift,
            whiteBalanceTint: whiteBalanceTint,
            aiDenoiseStrength: aiDenoiseStrength,
            shakeCorrectionStrength: shakeCorrectionStrength,
            faceRestorationStrength: faceRestorationStrength,
            faceRegion: faceRegion,
            rotationDegrees: rotationDegrees,
            cropAspect: cropAspect,
            cropCustomRatio: cropCustomRatio,
            cropZoom: cropZoom,
            cropOffsetX: cropOffsetX,
            cropOffsetY: cropOffsetY,
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

    @MainActor
    private func loadSelectedMetadata() async {
        guard let selectedSource else {
            selectedMetadata = nil
            return
        }
        selectedMetadata = await Task.detached {
            PhotoMetadata.load(from: selectedSource)
        }.value
    }
}
