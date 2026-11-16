import AppKit
import QuickLookThumbnailing
import SwiftUI

struct ThumbnailCard: View {
    let item: BatchItem
    let isPreviewed: Bool
    let isIncluded: Bool
    let onPreview: () -> Void
    let onToggleIncluded: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.88))

                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }

                    statusBadge
                        .padding(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .aspectRatio(4 / 3, contentMode: .fit)

                Text(item.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(isPreviewed ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isPreviewed ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isPreviewed ? 2 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onPreview)

            Button(action: onToggleIncluded) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isIncluded ? Color.white : Color.secondary, isIncluded ? Color.accentColor : Color.clear)
                    .padding(6)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(isIncluded ? localized("변환 대상에서 제외") : localized("변환 대상에 포함"))
        }
        .task(id: item.source) {
            await loadThumbnail()
        }
        .accessibilityLabel(localizedFormat("%@ 미리보기", item.displayName))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.state {
        case .waiting:
            EmptyView()
        case .processing:
            ProgressView()
                .controlSize(.mini)
                .padding(4)
                .background(.regularMaterial, in: Circle())
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, .green)
                .background(.regularMaterial, in: Circle())
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .padding(4)
                .background(.regularMaterial, in: Circle())
        }
    }

    @MainActor
    private func loadThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.source,
            size: CGSize(width: 360, height: 270),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            thumbnail = representation.nsImage
        } catch {
            thumbnail = NSWorkspace.shared.icon(forFile: item.source.path)
        }
    }
}
