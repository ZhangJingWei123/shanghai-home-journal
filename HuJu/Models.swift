import Foundation
import MapKit

enum PropertyStatus: String, Codable, CaseIterable, Identifiable {
    case visited = "已看"
    case shortlisted = "候选"
    case revisit = "复看"
    case archived = "排除"

    var id: String { rawValue }
}

struct PropertyListing: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var district: String
    var area: String
    var latitude: Double
    var longitude: Double
    var totalPrice: Double
    var unitPrice: Int
    var size: Double
    var rooms: String
    var visitDate: Date
    var status: PropertyStatus
    var score: Int
    var commuteMinutes: Int
    var tags: [String]
    var highlights: [String]
    var concerns: [String]
    var note: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct BudgetProfile: Codable, Equatable {
    var totalBudget: Double = 650
    var availableCash: Double = 230
    var monthlyIncome: Double = 5.8
    var loanYears: Int = 30
    var annualRate: Double = 3.05
    var isFirstHome: Bool = true
}

struct BudgetSnapshot: Equatable {
    let downPayment: Double
    let estimatedTaxesAndFees: Double
    let reserve: Double
    let monthlyPayment: Double
    let cashGap: Double
    let monthlyPaymentRatio: Double

    var isComfortable: Bool {
        cashGap <= 0 && monthlyPaymentRatio <= 0.4
    }
}

enum BudgetEngine {
    static func snapshot(for profile: BudgetProfile) -> BudgetSnapshot {
        let downPaymentRatio = profile.isFirstHome ? 0.15 : 0.25
        let downPayment = profile.totalBudget * downPaymentRatio
        let taxesAndFees = profile.totalBudget * 0.025
        let reserve = max(20, profile.totalBudget * 0.04)
        let principal = max(0, profile.totalBudget - downPayment)
        let monthlyRate = profile.annualRate / 100 / 12
        let months = Double(profile.loanYears * 12)
        let factor = pow(1 + monthlyRate, months)
        let payment = monthlyRate == 0
            ? principal / months
            : principal * monthlyRate * factor / (factor - 1)
        let requiredCash = downPayment + taxesAndFees + reserve

        return BudgetSnapshot(
            downPayment: downPayment,
            estimatedTaxesAndFees: taxesAndFees,
            reserve: reserve,
            monthlyPayment: payment,
            cashGap: requiredCash - profile.availableCash,
            monthlyPaymentRatio: profile.monthlyIncome > 0 ? payment / profile.monthlyIncome : 1
        )
    }
}

struct AIInsight: Identifiable, Equatable {
    enum Tone {
        case positive
        case warning
        case neutral
    }

    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    let tone: Tone
}

struct AIRecommendation: Equatable {
    let property: PropertyListing
    let fitScore: Int
    let reasons: [String]
    let missingChecks: [String]
}

protocol AIAdvising {
    func recommendations(
        listings: [PropertyListing],
        profile: BudgetProfile
    ) -> [AIRecommendation]

    func insights(
        listings: [PropertyListing],
        profile: BudgetProfile
    ) -> [AIInsight]
}

struct LocalAIAdvisor: AIAdvising {
    func recommendations(
        listings: [PropertyListing],
        profile: BudgetProfile
    ) -> [AIRecommendation] {
        listings
            .filter { $0.status != .archived }
            .map { listing in
                let budgetFit = max(0, 35 - Int(abs(listing.totalPrice - profile.totalBudget) / 12))
                let commuteFit = max(0, 25 - max(0, listing.commuteMinutes - 30))
                let evidenceFit = min(20, listing.highlights.count * 4 + listing.concerns.count * 3)
                let personalFit = min(20, listing.score * 2)
                let score = min(100, budgetFit + commuteFit + evidenceFit + personalFit)

                var reasons = [
                    listing.totalPrice <= profile.totalBudget
                        ? "总价在当前预算内"
                        : "总价超预算 \(Int(listing.totalPrice - profile.totalBudget)) 万",
                    "通勤约 \(listing.commuteMinutes) 分钟",
                    "现场评分 \(listing.score)/10"
                ]
                if let highlight = listing.highlights.first {
                    reasons.append(highlight)
                }

                var missing: [String] = []
                if !listing.concerns.contains(where: { $0.contains("噪音") }) {
                    missing.append("晚高峰噪音")
                }
                if !listing.tags.contains(where: { $0.contains("产权") }) {
                    missing.append("产权与抵押核验")
                }
                if !listing.tags.contains(where: { $0.contains("物业") }) {
                    missing.append("物业费与维修记录")
                }

                return AIRecommendation(
                    property: listing,
                    fitScore: score,
                    reasons: reasons,
                    missingChecks: missing
                )
            }
            .sorted { $0.fitScore > $1.fitScore }
    }

    func insights(
        listings: [PropertyListing],
        profile: BudgetProfile
    ) -> [AIInsight] {
        guard !listings.isEmpty else {
            return [
                AIInsight(
                    title: "先记录第一套",
                    detail: "完成一次结构化看房后，我会开始识别你的真实偏好。",
                    symbol: "sparkles",
                    tone: .neutral
                )
            ]
        }

        let snapshot = BudgetEngine.snapshot(for: profile)
        let averageCommute = listings.map(\.commuteMinutes).reduce(0, +) / listings.count
        let commonDistrict = Dictionary(grouping: listings, by: \.district)
            .max(by: { $0.value.count < $1.value.count })?.key ?? "上海"

        var result = [
            AIInsight(
                title: "偏好正在收敛",
                detail: "你在 \(commonDistrict) 记录最多，平均通勤 \(averageCommute) 分钟。下一轮建议只看 2 个相邻板块。",
                symbol: "scope",
                tone: .positive
            )
        ]

        if snapshot.monthlyPaymentRatio > 0.4 {
            result.append(
                AIInsight(
                    title: "月供压力偏高",
                    detail: "估算月供占家庭月收入 \(Int(snapshot.monthlyPaymentRatio * 100))%。建议保留应急金后再确定上限。",
                    symbol: "exclamationmark.triangle.fill",
                    tone: .warning
                )
            )
        } else {
            result.append(
                AIInsight(
                    title: "现金流在舒适区",
                    detail: "估算月供占家庭月收入 \(Int(snapshot.monthlyPaymentRatio * 100))%，仍需向银行确认实际利率与额度。",
                    symbol: "checkmark.seal.fill",
                    tone: .positive
                )
            )
        }

        result.append(
            AIInsight(
                title: "证据缺口",
                detail: "多数记录缺少夜间噪音、物业维修和产权核验。复看时优先补齐，而不是继续扩充候选。",
                symbol: "doc.text.magnifyingglass",
                tone: .neutral
            )
        )
        return result
    }
}
