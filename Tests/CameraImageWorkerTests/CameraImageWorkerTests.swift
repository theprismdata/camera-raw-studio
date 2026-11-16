import Foundation
import Testing
@testable import CameraImageWorker

@Test("JPEG 출력 이름은 원본 파일명을 유지한다")
func outputNamePreservesSourceStem() {
    // Given
    let source = URL(fileURLWithPath: "/input/DSC00042.ARW")
    let destination = URL(fileURLWithPath: "/output")

    // When
    let output = RawProcessor.outputURL(for: source, in: destination)

    // Then
    #expect(output.path == "/output/DSC00042.jpg")
}

@Test("사용자 렌즈는 입력한 광학 값을 보존한다")
func customLensPreservesOpticalValues() {
    // Given
    let focalLength = 23.0
    let aperture = 1.4
    let correction = 0.08

    // When
    let lens = LensProfile.custom(
        focalLength: focalLength,
        aperture: aperture,
        correction: correction
    )

    // Then
    #expect(lens.focalLength == focalLength)
    #expect(lens.aperture == aperture)
    #expect(lens.distortionCorrection == correction)
}

@Test("사진 폴더는 지원 파일을 하위 폴더까지 찾는다")
func photoFolderFindsSupportedFilesRecursively() throws {
    // Given
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let nested = root.appendingPathComponent("nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data().write(to: root.appendingPathComponent("first.ARW"))
    try Data().write(to: nested.appendingPathComponent("second.jpg"))
    try Data().write(to: root.appendingPathComponent("ignore.mp4"))

    // When
    let files = try PhotoDiscovery.files(in: root)

    // Then
    #expect(files.map(\.lastPathComponent).sorted() == ["first.ARW", "second.jpg"])
}

@Test("화이트밸런스 조정 대상은 RAW 파일뿐이다")
func whiteBalanceOnlySupportsRawFiles() {
    // Given
    let raw = URL(fileURLWithPath: "/input/photo.ARW")
    let jpeg = URL(fileURLWithPath: "/input/photo.jpg")

    // When
    let rawSupportsWhiteBalance = PhotoDiscovery.isRaw(raw)
    let jpegSupportsWhiteBalance = PhotoDiscovery.isRaw(jpeg)

    // Then
    #expect(rawSupportsWhiteBalance)
    #expect(!jpegSupportsWhiteBalance)
}

@Test("수평 회전은 검은 모서리를 피하도록 이미지를 확대한다")
func straighteningScaleCoversRotatedCorners() {
    // Given
    let width = 6_000.0
    let height = 4_000.0

    // When
    let unchanged = RawProcessor.straighteningScale(width: width, height: height, radians: 0)
    let rotated = RawProcessor.straighteningScale(width: width, height: height, radians: 5 * .pi / 180)

    // Then
    #expect(unchanged == 1)
    #expect(rotated > 1)
}

@Test("크롭 비율과 위치를 이미지 범위 안에서 계산한다")
func cropRectUsesAspectZoomAndPosition() {
    let extent = CGRect(x: 0, y: 0, width: 6_000, height: 4_000)

    let centered = RawProcessor.cropRect(
        in: extent,
        aspect: .square,
        zoom: 1,
        offsetX: 0,
        offsetY: 0
    )
    let moved = RawProcessor.cropRect(
        in: extent,
        aspect: .square,
        zoom: 2,
        offsetX: 1,
        offsetY: 1
    )

    #expect(centered.width == centered.height)
    #expect(centered == CGRect(x: 1_000, y: 0, width: 4_000, height: 4_000))
    #expect(moved.width == 2_000)
    #expect(moved.maxX == extent.maxX)
    #expect(moved.minY == extent.minY)
}

@Test("기존 편집 파일에는 기본 크롭 값이 적용된다")
func oldSettingsDecodeWithDefaultCrop() throws {
    let json = """
    {
      "exposure": 0,
      "contrast": 1.05,
      "saturation": 1,
      "whiteBalanceTemperatureShift": 0,
      "whiteBalanceTint": 0,
      "aiDenoiseStrength": "off",
      "rotationDegrees": 0,
      "jpegQuality": 0.92,
      "lens": {
        "id": "sony-e-11-f1.8",
        "name": "Sony E 11mm F1.8",
        "focalLength": 11,
        "aperture": 1.8,
        "distortionCorrection": 0.1
      }
    }
    """

    let settings = try JSONDecoder().decode(DevelopSettings.self, from: Data(json.utf8))

    #expect(settings.cropAspect == .original)
    #expect(settings.cropCustomRatio == 1)
    #expect(settings.cropZoom == 1)
    #expect(settings.cropOffsetX == 0)
    #expect(settings.cropOffsetY == 0)
    #expect(settings.shakeCorrectionStrength == .off)
    #expect(settings.faceRestorationStrength == .off)
    #expect(settings.faceRegion == nil)
    #expect(settings.highlights == 0)
    #expect(settings.shadows == 0)
    #expect(settings.whites == 0)
    #expect(settings.blacks == 0)
    #expect(settings.vignetteAmount == 0)
    #expect(settings.grainAmount == 0)
    #expect(settings.perspectiveVertical == 0)
    #expect(settings.perspectiveHorizontal == 0)
}

@Test("편집 내용은 사진 폴더에서 다시 복원된다")
func savedEditsRoundTripInPhotoFolder() throws {
    // Given
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let document = SavedEditDocument(
        editMode: .individual,
        globalSettings: .defaultSettings,
        settingsByRelativePath: ["photo.ARW": .defaultSettings],
        selectedRelativePaths: ["photo.ARW"],
        previewedRelativePath: "photo.ARW"
    )

    // When
    try EditStore.save(document, in: folder)
    let restored = try EditStore.load(from: folder)

    // Then
    #expect(restored == document)
}

@Test("현재 사진 저장은 기존 편집본을 덮어쓰지 않는다")
func editedOutputChoosesANewNameWhenFileExists() throws {
    // Given
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data().write(to: folder.appendingPathComponent("photo_edit.jpg"))
    let source = folder.appendingPathComponent("photo.ARW")

    // When
    let output = RawProcessor.availableEditedOutputURL(for: source, in: folder)

    // Then
    #expect(output.lastPathComponent == "photo_edit_2.jpg")
}
