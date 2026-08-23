import Foundation

@MainActor
final class PropertyStore: ObservableObject {
    @Published private(set) var listings: [PropertyListing]
    @Published var budget: BudgetProfile {
        didSet { persist() }
    }

    private let defaults: UserDefaults?
    private let listingsKey = "huju.listings.v1"
    private let budgetKey = "huju.budget.v1"

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults

        if
            let data = defaults?.data(forKey: listingsKey),
            let stored = try? JSONDecoder().decode([PropertyListing].self, from: data)
        {
            listings = stored
        } else {
            listings = Self.samples
        }

        if
            let data = defaults?.data(forKey: budgetKey),
            let stored = try? JSONDecoder().decode(BudgetProfile.self, from: data)
        {
            budget = stored
        } else {
            budget = BudgetProfile()
        }
    }

    func add(_ listing: PropertyListing) {
        listings.insert(listing, at: 0)
        persist()
    }

    func updateStatus(_ status: PropertyStatus, for id: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == id }) else { return }
        listings[index].status = status
        persist()
    }

    private func persist() {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(listings) {
            defaults.set(data, forKey: listingsKey)
        }
        if let data = try? JSONEncoder().encode(budget) {
            defaults.set(data, forKey: budgetKey)
        }
    }

    static let samples: [PropertyListing] = [
        PropertyListing(
            id: UUID(uuidString: "6A1038EF-0905-47DD-9827-E29578C2A90A")!,
            name: "万科翡翠公园",
            district: "浦东新区",
            area: "张江",
            latitude: 31.2038,
            longitude: 121.6244,
            totalPrice: 635,
            unitPrice: 79_400,
            size: 80,
            rooms: "2室2厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
            status: .shortlisted,
            score: 9,
            commuteMinutes: 38,
            tags: ["次新", "近地铁", "物业已问"],
            highlights: ["南向客厅采光稳定", "社区步行体验完整", "张江通勤可控"],
            concerns: ["次卧尺度偏紧", "晚高峰噪音待复核"],
            note: "小区秩序和公共空间明显优于前两套，适合二次带家人复看。"
        ),
        PropertyListing(
            id: UUID(uuidString: "AFAF315E-54A5-4C51-918D-A55BF902AB00")!,
            name: "大华锦绣华城",
            district: "浦东新区",
            area: "北蔡",
            latitude: 31.1791,
            longitude: 121.5594,
            totalPrice: 598,
            unitPrice: 68_700,
            size: 87,
            rooms: "2室2厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
            status: .revisit,
            score: 8,
            commuteMinutes: 44,
            tags: ["成熟配套", "产权待核验"],
            highlights: ["户型方正", "商业和生活配套成熟", "总价留有装修空间"],
            concerns: ["楼龄更长", "早高峰换乘拥挤"],
            note: "总价舒服，生活便利。需要复看楼栋噪音并查询近一年同户型成交。"
        ),
        PropertyListing(
            id: UUID(uuidString: "0D309EE1-FC91-4DA9-A3C0-7E47307E6798")!,
            name: "中海寰宇时代",
            district: "闵行区",
            area: "华漕",
            latitude: 31.2167,
            longitude: 121.3017,
            totalPrice: 688,
            unitPrice: 71_600,
            size: 96,
            rooms: "3室2厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -12, to: .now)!,
            status: .visited,
            score: 7,
            commuteMinutes: 58,
            tags: ["新房", "三房", "物业已问"],
            highlights: ["三房成长性更好", "社区景观完整"],
            concerns: ["超出预算", "通勤时间长", "周边兑现周期不确定"],
            note: "产品力很好，但预算和通勤都在拉扯，需要与张江两房做十年成本比较。"
        ),
        PropertyListing(
            id: UUID(uuidString: "B4BE2B1A-BA28-488F-91F3-D7F4A430B78A")!,
            name: "新江湾城时代花园",
            district: "杨浦区",
            area: "新江湾城",
            latitude: 31.3266,
            longitude: 121.5056,
            totalPrice: 760,
            unitPrice: 91_600,
            size: 83,
            rooms: "2室2厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -18, to: .now)!,
            status: .archived,
            score: 7,
            commuteMinutes: 49,
            tags: ["生态", "近地铁"],
            highlights: ["街区安静", "公园资源突出"],
            concerns: ["明显超预算", "可选户型少"],
            note: "居住感不错，但会显著压缩现金储备，现阶段排除。"
        )
    ]
}
