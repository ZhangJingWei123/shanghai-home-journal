import SwiftUI

enum HuJuTheme {
    static let ink = Color(red: 0.08, green: 0.11, blue: 0.14)
    static let paper = Color(red: 0.96, green: 0.97, blue: 0.96)
    static let green = Color(red: 0.05, green: 0.48, blue: 0.35)
    static let coral = Color(red: 0.92, green: 0.32, blue: 0.25)
    static let blue = Color(red: 0.12, green: 0.38, blue: 0.72)
    static let yellow = Color(red: 0.96, green: 0.72, blue: 0.18)
    static let muted = Color(red: 0.39, green: 0.43, blue: 0.45)
    static let line = Color.black.opacity(0.09)
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
            .background(tint.opacity(0.09))
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
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HuJuTheme.green)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(HuJuTheme.ink)
            }
            Spacer()
            if let action {
                Text(action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HuJuTheme.blue)
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
                .stroke(HuJuTheme.line, lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 10)
                .stroke(
                    score >= 8 ? HuJuTheme.green : HuJuTheme.yellow,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
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

struct PropertyRow: View {
    let listing: PropertyListing

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(HuJuTheme.green.opacity(0.12))
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HuJuTheme.green)
            }
            .frame(width: 54, height: 62)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(listing.name)
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    StatusBadge(status: listing.status)
                }
                Text("\(listing.district) · \(listing.area) · \(listing.rooms)")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                HStack {
                    Text("\(Int(listing.totalPrice)) 万")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HuJuTheme.coral)
                    Text("· \(Int(listing.size))m²")
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                    Spacer()
                    Label("\(listing.commuteMinutes) min", systemImage: "tram.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.blue)
                }
            }

            ScoreRing(score: listing.score, diameter: 42)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HuJuTheme.line)
        }
    }
}
