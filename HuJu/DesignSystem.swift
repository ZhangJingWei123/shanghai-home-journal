import MapKit
import SwiftUI
import UIKit

enum HuJuTheme {
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.11)
    static let paper = Color(red: 0.972, green: 0.976, blue: 0.972)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.94, green: 0.948, blue: 0.942)
    static let deepGreen = Color(red: 0.10, green: 0.20, blue: 0.16)
    static let green = Color(red: 0.07, green: 0.43, blue: 0.32)
    static let coral = Color(red: 0.83, green: 0.32, blue: 0.24)
    static let blue = Color(red: 0.23, green: 0.40, blue: 0.57)
    static let yellow = Color(red: 0.72, green: 0.52, blue: 0.17)
    static let muted = Color(red: 0.39, green: 0.42, blue: 0.41)
    static let line = Color(red: 0.88, green: 0.89, blue: 0.88)
    static let shadow = Color.black.opacity(0.04)
}

private struct HuJuCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(HuJuTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: HuJuTheme.shadow, radius: 8, x: 0, y: 3)
    }
}

extension View {
    func hujuCard() -> some View {
        modifier(HuJuCardModifier())
    }
}

struct HuJuIconTile: View {
    let symbol: String
    var color: Color = HuJuTheme.green
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct MetricPill: View {
    let symbol: String
    let text: String
    var tint: Color = HuJuTheme.ink

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(HuJuTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    var action: String?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HuJuTheme.muted)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(HuJuTheme.ink)
            }
            Spacer()
            if let action {
                Text(action)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HuJuTheme.green)
            }
        }
    }
}

struct ScoreRing: View {
    let score: Int
    var diameter: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .stroke(HuJuTheme.line, lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 10)
                .stroke(
                    score >= 8 ? HuJuTheme.green : HuJuTheme.yellow,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(HuJuTheme.ink)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("现场评分 \(score) 分")
    }
}

struct StatusBadge: View {
    let status: PropertyStatus

    private var color: Color {
        switch status {
        case .visited: HuJuTheme.blue
        case .shortlisted: HuJuTheme.green
        case .revisit: HuJuTheme.coral
        case .archived: HuJuTheme.muted
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private enum PropertyMediaPreview {
    static func firstPhoto(for listing: PropertyListing) -> UIImage? {
        guard
            let attachment = listing.mediaAttachments?.first(where: { $0.kind == .photo }),
            let base = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        else {
            return nil
        }

        let url = base
            .appendingPathComponent("PropertyMedia", isDirectory: true)
            .appendingPathComponent(attachment.fileName)
        return UIImage(contentsOfFile: url.path)
    }
}

struct PropertyEvidenceVisual: View {
    let listing: PropertyListing
    var height: CGFloat = 124

    private var capturedPhoto: UIImage? {
        PropertyMediaPreview.firstPhoto(for: listing)
    }

    private var mapPosition: MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: listing.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
    }

    var body: some View {
        Group {
            if let capturedPhoto {
                Image(uiImage: capturedPhoto)
                    .resizable()
                    .scaledToFill()
            } else {
                Map(initialPosition: mapPosition, interactionModes: []) {
                    Annotation("", coordinate: listing.coordinate) {
                        Image(systemName: "house.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(HuJuTheme.green)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted))
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            Text("\(listing.district) · \(listing.area)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HuJuTheme.ink)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(
            capturedPhoto == nil
                ? "\(listing.name)的位置地图"
                : "\(listing.name)的现场照片"
        )
    }
}

struct PropertyListRow: View {
    let listing: PropertyListing

    private var capturedPhoto: UIImage? {
        PropertyMediaPreview.firstPhoto(for: listing)
    }

    var body: some View {
        HStack(spacing: 13) {
            Group {
                if let capturedPhoto {
                    Image(uiImage: capturedPhoto)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 2) {
                        Text("到访")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(HuJuTheme.muted)
                        Text(listing.visitDate, format: .dateTime.month().day())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HuJuTheme.ink)
                    }
                }
            }
            .frame(width: 62, height: 62)
            .background(HuJuTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(listing.name)
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    StatusBadge(status: listing.status)
                }
                Text("\(listing.resolvedUnitLabel) · \(listing.locationSummary)")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(Int(listing.totalPrice)) 万")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                    Label("\(listing.commuteMinutes) 分钟", systemImage: "tram.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.muted)
                    Spacer()
                    Text("\(listing.score) 分")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HuJuTheme.green)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

struct PropertyRow: View {
    let listing: PropertyListing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertyEvidenceVisual(listing: listing)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(listing.name)
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    StatusBadge(status: listing.status)
                }
                Text(listing.resolvedUnitLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HuJuTheme.ink)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(Int(listing.totalPrice)) 万")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text("\(Int(listing.size)) 平")
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                    Label("\(listing.commuteMinutes) 分钟", systemImage: "tram.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.muted)
                    Spacer()
                    Text("\(listing.score) 分")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HuJuTheme.green)
                }
            }
            .padding(14)
        }
        .hujuCard()
    }
}
