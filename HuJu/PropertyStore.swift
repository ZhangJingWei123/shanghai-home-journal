import Foundation

@MainActor
final class PropertyStore: ObservableObject {
    @Published private(set) var listings: [PropertyListing]
    @Published private(set) var partnerScores: [UUID: Int]
    @Published private(set) var isUsingSampleData: Bool
    @Published private(set) var selectedCity: String?
    @Published var budget: BudgetProfile {
        didSet { persist() }
    }

    var visibleListings: [PropertyListing] {
        guard let selectedCity else { return listings }
        return listings.filter { $0.resolvedCity == selectedCity }
    }

    var cityOptions: [String] {
        CityCatalog.ordered(
            MarketDataLoader.bundled.cityNames + listings.map(\.resolvedCity)
        )
    }

    var cityScopeTitle: String {
        selectedCity ?? "全国"
    }

    private let defaults: UserDefaults?
    private let listingsKey = "huju.listings.v1"
    private let budgetKey = "huju.budget.v1"
    private let partnerScoresKey = "huju.partner-scores.v1"
    private let retiredTaskStateKey = "huju.buying-plan.v1"
    private let sampleDataKey = "huju.uses-sample-data.v1"
    private let selectedCityKey = "huju.selected-city.v1"

    init(defaults: UserDefaults? = .standard, loadsSampleData: Bool = false) {
        self.defaults = defaults
        selectedCity = defaults?.string(forKey: selectedCityKey).map(CityCatalog.normalized)

        if
            let data = defaults?.data(forKey: listingsKey),
            let stored = try? JSONDecoder().decode([PropertyListing].self, from: data)
        {
            listings = stored
            if defaults?.object(forKey: sampleDataKey) != nil {
                isUsingSampleData = defaults?.bool(forKey: sampleDataKey) ?? false
            } else {
                let storedIDs = Set(stored.map(\.id))
                isUsingSampleData = !storedIDs.isEmpty
                    && storedIDs.isSubset(of: Set(Self.samples.map(\.id)))
            }
        } else if loadsSampleData {
            listings = Self.samples
            isUsingSampleData = true
        } else {
            listings = []
            isUsingSampleData = false
        }

        if
            let data = defaults?.data(forKey: partnerScoresKey),
            let stored = try? JSONDecoder().decode([UUID: Int].self, from: data)
        {
            partnerScores = stored
        } else {
            partnerScores = [:]
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
        var listing = listing
        let cleanCity = CityCatalog.normalized(listing.city ?? "")
        if cleanCity.isEmpty {
            listing.city = selectedCity
        } else {
            listing.city = cleanCity
        }
        listing.availability = listing.availability ?? .active
        if listing.timeline?.isEmpty != false {
            listing.timeline = [PropertyTimelineEngine.discoveryEvent(for: listing)]
        }
        listings.insert(listing, at: 0)
        persist()
    }

    func selectCity(_ city: String?) {
        let cleanCity = CityCatalog.normalized(city ?? "")
        selectedCity = cleanCity.isEmpty ? nil : cleanCity
        persistSelectedCity()
    }

    func loadSampleData() {
        guard listings.isEmpty else { return }
        listings = Self.samples
        isUsingSampleData = true
        persist()
    }

    func deleteAllUserData() {
        let attachments = listings.flatMap { $0.mediaAttachments ?? [] }
        LocalPropertyMediaStore.remove(attachments)

        listings = []
        partnerScores = [:]
        isUsingSampleData = false
        selectedCity = nil
        budget = BudgetProfile()

        guard let defaults else { return }
        [
            listingsKey,
            budgetKey,
            partnerScoresKey,
            retiredTaskStateKey,
            sampleDataKey,
            selectedCityKey
        ]
            .forEach(defaults.removeObject(forKey:))
    }

    func update(_ listing: PropertyListing) {
        guard let index = listings.firstIndex(where: { $0.id == listing.id }) else { return }
        var listing = listing
        let cleanCity = CityCatalog.normalized(listing.city ?? "")
        listing.city = cleanCity.isEmpty ? nil : cleanCity
        listings[index] = listing
        persist()
    }

    func addMediaAttachment(_ attachment: PropertyMediaAttachment, for id: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == id }) else { return }
        var attachments = listings[index].mediaAttachments ?? []
        attachments.append(attachment)
        listings[index].mediaAttachments = attachments
        persist()
    }

    @discardableResult
    func recordTimelineEvent(
        _ kind: PropertyTimelineEventKind,
        for id: UUID,
        price: Double? = nil,
        sourceURL: String? = nil,
        note: String = "",
        occurredAt: Date = .now
    ) -> Bool {
        guard let index = listings.firstIndex(where: { $0.id == id }) else { return false }
        var listing = listings[index]
        var events = listing.timeline ?? [PropertyTimelineEngine.discoveryEvent(for: listing)]
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail: String
        var eventPrice: Double?
        var eventSource: String?

        switch kind {
        case .discovered:
            return false
        case .priceChanged:
            guard let price, price > 0, price != listing.totalPrice else { return false }
            detail = "挂牌价 \(Int(listing.totalPrice)) 万 → \(Int(price)) 万"
            listing.totalPrice = price
            listing.unitPrice = Int(price * 10_000 / listing.size)
            eventPrice = price
            eventSource = listing.sourceURL
        case .sourceUpdated:
            guard
                let sourceURL,
                !sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return false
            }
            let cleanSource = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
            detail = listing.sourceURL == nil ? "补充房源来源" : "房源来源链接已更新"
            listing.sourceURL = cleanSource
            eventPrice = listing.totalPrice
            eventSource = cleanSource
        case .revisited:
            detail = "完成一次复看"
            listing.visitDate = occurredAt
            listing.status = .revisit
            eventPrice = listing.totalPrice
            eventSource = listing.sourceURL
        case .delisted:
            detail = "房源状态变更为已下架"
            listing.availability = .delisted
            eventPrice = listing.totalPrice
            eventSource = listing.sourceURL
        case .relisted:
            let previousPrice = listing.totalPrice
            listing.availability = .active
            if let price, price > 0, price != previousPrice {
                listing.totalPrice = price
                listing.unitPrice = Int(price * 10_000 / listing.size)
                detail = "重新挂牌，价格 \(Int(previousPrice)) 万 → \(Int(price)) 万"
            } else {
                detail = "房源重新挂牌"
            }
            eventPrice = listing.totalPrice
            eventSource = listing.sourceURL
        case .sold:
            listing.availability = .sold
            if let price, price > 0 {
                detail = "房源已成交，记录价格 \(Int(price)) 万"
                eventPrice = price
            } else {
                detail = "房源状态变更为已成交"
                eventPrice = listing.totalPrice
            }
            eventSource = listing.sourceURL
        }

        let fullDetail = cleanNote.isEmpty ? detail : "\(detail) · \(cleanNote)"
        events.append(
            PropertyTimelineEvent(
                id: UUID(),
                kind: kind,
                occurredAt: occurredAt,
                detail: fullDetail,
                price: eventPrice,
                sourceURL: eventSource
            )
        )
        listing.timeline = events
        listings[index] = listing
        persist()
        return true
    }

    func updateStatus(_ status: PropertyStatus, for id: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == id }) else { return }
        listings[index].status = status
        persist()
    }

    func setPartnerScore(_ score: Int, for id: UUID) {
        partnerScores[id] = min(10, max(1, score))
        persist()
    }

    func setEvidence(_ kind: VisitEvidenceKind, completed: Bool, for id: UUID) {
        guard let index = listings.firstIndex(where: { $0.id == id }) else { return }
        var evidence = Set(listings[index].verifiedEvidence ?? [])
        if completed {
            evidence.insert(kind)
        } else {
            evidence.remove(kind)
        }
        listings[index].verifiedEvidence = VisitEvidenceKind.allCases.filter(evidence.contains)
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
        if let data = try? JSONEncoder().encode(partnerScores) {
            defaults.set(data, forKey: partnerScoresKey)
        }
        defaults.set(isUsingSampleData, forKey: sampleDataKey)
    }

    private func persistSelectedCity() {
        guard let defaults else { return }
        if let selectedCity {
            defaults.set(selectedCity, forKey: selectedCityKey)
        } else {
            defaults.removeObject(forKey: selectedCityKey)
        }
    }

    static let samples: [PropertyListing] = [
        PropertyListing(
            id: UUID(uuidString: "6A1038EF-0905-47DD-9827-E29578C2A90A")!,
            name: "万科翡翠公园",
            city: "上海",
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
            note: "小区秩序和公共空间明显优于前两套，适合二次带家人复看。",
            availability: .active,
            timeline: [
                PropertyTimelineEvent(
                    id: UUID(uuidString: "5A8FB671-0FC6-4192-8E0B-E06F49DC7B9A")!,
                    kind: .discovered,
                    occurredAt: Calendar.current.date(byAdding: .day, value: -30, to: .now)!,
                    detail: "首次记录挂牌价 668 万",
                    price: 668,
                    sourceURL: nil
                ),
                PropertyTimelineEvent(
                    id: UUID(uuidString: "7C737B26-43F7-4D49-936A-33C5DB169B27")!,
                    kind: .priceChanged,
                    occurredAt: Calendar.current.date(byAdding: .day, value: -10, to: .now)!,
                    detail: "挂牌价 668 万 → 648 万",
                    price: 648,
                    sourceURL: nil
                ),
                PropertyTimelineEvent(
                    id: UUID(uuidString: "CE89D609-A61F-4942-BAB5-5BD58E2A9D6A")!,
                    kind: .priceChanged,
                    occurredAt: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
                    detail: "挂牌价 648 万 → 635 万",
                    price: 635,
                    sourceURL: nil
                )
            ],
            unitLabel: "南向两房",
            building: "12 号楼",
            floorDescription: "中楼层"
        ),
        PropertyListing(
            id: UUID(uuidString: "AFAF315E-54A5-4C51-918D-A55BF902AB00")!,
            name: "大华锦绣华城",
            city: "上海",
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
            note: "总价舒服，生活便利。需要复看楼栋噪音并查询近一年同户型成交。",
            unitLabel: "方正两房",
            building: "6 号楼",
            floorDescription: "高楼层"
        ),
        PropertyListing(
            id: UUID(uuidString: "0D309EE1-FC91-4DA9-A3C0-7E47307E6798")!,
            name: "中海寰宇时代",
            city: "上海",
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
            note: "产品力很好，但预算和通勤都在拉扯，需要与张江两房做十年成本比较。",
            unitLabel: "三房",
            building: "3 号楼",
            floorDescription: "中高楼层"
        ),
        PropertyListing(
            id: UUID(uuidString: "B4BE2B1A-BA28-488F-91F3-D7F4A430B78A")!,
            name: "新江湾城时代花园",
            city: "上海",
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
            note: "居住感不错，但会显著压缩现金储备，现阶段排除。",
            unitLabel: "两房",
            building: "9 号楼",
            floorDescription: "低楼层"
        ),
        PropertyListing(
            id: UUID(uuidString: "CAFE0810-9AB7-4B70-A82A-F4E0D5AA38C1")!,
            name: "望京示例房源",
            city: "北京",
            district: "朝阳区",
            area: "望京",
            latitude: 39.9961,
            longitude: 116.4753,
            totalPrice: 720,
            unitPrice: 86_700,
            size: 83,
            rooms: "2室1厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -4, to: .now)!,
            status: .shortlisted,
            score: 8,
            commuteMinutes: 35,
            tags: ["近地铁", "生活便利"],
            highlights: ["通勤时间可控", "周边生活配套成熟"],
            concerns: ["总价接近上限", "夜间噪音待复核"],
            note: "用于演示跨城市看房记录，具体信息不代表真实在售房源。",
            unitLabel: "示例两房",
            building: "5 号楼",
            floorDescription: "中楼层"
        ),
        PropertyListing(
            id: UUID(uuidString: "7FA2C962-B7B1-44CE-8B8C-5314D96D42D2")!,
            name: "未来科技城示例房源",
            city: "杭州",
            district: "余杭区",
            area: "未来科技城",
            latitude: 30.2815,
            longitude: 120.0188,
            totalPrice: 420,
            unitPrice: 46_700,
            size: 90,
            rooms: "3室2厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -9, to: .now)!,
            status: .visited,
            score: 8,
            commuteMinutes: 42,
            tags: ["三房", "次新"],
            highlights: ["空间利用率较高", "预算留有余量"],
            concerns: ["通勤换乘需要复核", "周边建设周期待确认"],
            note: "用于演示不同城市的预算与通勤比较。",
            unitLabel: "示例三房",
            building: "8 号楼",
            floorDescription: "高楼层"
        ),
        PropertyListing(
            id: UUID(uuidString: "3772A09C-FA2D-4DA7-B353-5C2A98F70111")!,
            name: "金融城示例房源",
            city: "成都",
            district: "武侯区",
            area: "金融城",
            latitude: 30.5755,
            longitude: 104.0648,
            totalPrice: 330,
            unitPrice: 34_700,
            size: 95,
            rooms: "3室2厅",
            visitDate: Calendar.current.date(byAdding: .day, value: -15, to: .now)!,
            status: .revisit,
            score: 9,
            commuteMinutes: 28,
            tags: ["通勤便利", "物业已问"],
            highlights: ["家庭空间充足", "通勤与预算平衡"],
            concerns: ["雨季渗水记录待核验"],
            note: "用于演示全国城市间的看房记录与证据管理。",
            unitLabel: "示例改善三房",
            building: "2 号楼",
            floorDescription: "中高楼层"
        )
    ]
}
