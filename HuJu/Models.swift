import Foundation
import MapKit

enum PropertyStatus: String, Codable, CaseIterable, Identifiable {
    case visited = "已看"
    case shortlisted = "候选"
    case revisit = "复看"
    case archived = "排除"

    var id: String { rawValue }
}

enum ListingAvailability: String, Codable, CaseIterable, Identifiable {
    case active = "在售"
    case delisted = "已下架"
    case sold = "已成交"

    var id: String { rawValue }
}

enum PropertyTimelineEventKind: String, Codable, CaseIterable, Identifiable {
    case discovered
    case priceChanged
    case sourceUpdated
    case revisited
    case delisted
    case relisted
    case sold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discovered: "首次记录"
        case .priceChanged: "挂牌价变化"
        case .sourceUpdated: "来源更新"
        case .revisited: "完成复看"
        case .delisted: "房源下架"
        case .relisted: "重新挂牌"
        case .sold: "房源成交"
        }
    }

    var symbol: String {
        switch self {
        case .discovered: "bookmark.fill"
        case .priceChanged: "arrow.up.arrow.down"
        case .sourceUpdated: "link"
        case .revisited: "eye.fill"
        case .delisted: "pause.circle.fill"
        case .relisted: "arrow.clockwise.circle.fill"
        case .sold: "checkmark.seal.fill"
        }
    }
}

struct PropertyTimelineEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: PropertyTimelineEventKind
    let occurredAt: Date
    let detail: String
    let price: Double?
    let sourceURL: String?
}

enum PropertyMediaKind: String, Codable, Hashable {
    case photo
    case video

    var title: String {
        switch self {
        case .photo: "照片"
        case .video: "视频"
        }
    }

    var symbol: String {
        switch self {
        case .photo: "photo.fill"
        case .video: "video.fill"
        }
    }
}

struct PropertyMediaAttachment: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: PropertyMediaKind
    let fileName: String
    let createdAt: Date
}

struct PropertyListing: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var city: String? = nil
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
    var buildYear: Int? = nil
    var orientation: String? = nil
    var metroDistanceMeters: Int? = nil
    var sourceURL: String? = nil
    var verifiedEvidence: [VisitEvidenceKind]? = nil
    var availability: ListingAvailability? = nil
    var timeline: [PropertyTimelineEvent]? = nil
    var mediaAttachments: [PropertyMediaAttachment]? = nil
    var unitLabel: String? = nil
    var building: String? = nil
    var floorDescription: String? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var resolvedCity: String {
        let cleanCity = CityCatalog.normalized(city ?? "")
        return cleanCity.isEmpty ? "上海" : cleanCity
    }

    var resolvedUnitLabel: String {
        let cleanLabel = unitLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleanLabel.isEmpty
            ? "\(Int(size)) 平方米 · \(rooms)"
            : cleanLabel
    }

    var locationSummary: String {
        let details = [
            resolvedCity,
            district,
            area,
            building?.trimmingCharacters(in: .whitespacesAndNewlines),
            floorDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return details.joined(separator: " · ")
    }
}

enum CityCatalog {
    static let popularCities = [
        "北京", "上海", "广州", "深圳", "杭州", "南京",
        "苏州", "成都", "武汉", "重庆", "西安", "天津"
    ]

    private static let centers: [String: CLLocationCoordinate2D] = [
        "北京": CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        "上海": CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        "广州": CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644),
        "深圳": CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579),
        "杭州": CLLocationCoordinate2D(latitude: 30.2741, longitude: 120.1551),
        "南京": CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969),
        "苏州": CLLocationCoordinate2D(latitude: 31.2989, longitude: 120.5853),
        "成都": CLLocationCoordinate2D(latitude: 30.5728, longitude: 104.0668),
        "武汉": CLLocationCoordinate2D(latitude: 30.5928, longitude: 114.3055),
        "重庆": CLLocationCoordinate2D(latitude: 29.4316, longitude: 106.9123),
        "西安": CLLocationCoordinate2D(latitude: 34.3416, longitude: 108.9398),
        "天津": CLLocationCoordinate2D(latitude: 39.3434, longitude: 117.3616),
        "长沙": CLLocationCoordinate2D(latitude: 28.2282, longitude: 112.9388),
        "郑州": CLLocationCoordinate2D(latitude: 34.7466, longitude: 113.6254),
        "青岛": CLLocationCoordinate2D(latitude: 36.0671, longitude: 120.3826),
        "济南": CLLocationCoordinate2D(latitude: 36.6512, longitude: 117.1201),
        "合肥": CLLocationCoordinate2D(latitude: 31.8206, longitude: 117.2272),
        "厦门": CLLocationCoordinate2D(latitude: 24.4798, longitude: 118.0894),
        "福州": CLLocationCoordinate2D(latitude: 26.0745, longitude: 119.2965),
        "宁波": CLLocationCoordinate2D(latitude: 29.8683, longitude: 121.5440),
        "无锡": CLLocationCoordinate2D(latitude: 31.4912, longitude: 120.3119),
        "沈阳": CLLocationCoordinate2D(latitude: 41.8057, longitude: 123.4315),
        "大连": CLLocationCoordinate2D(latitude: 38.9140, longitude: 121.6147),
        "哈尔滨": CLLocationCoordinate2D(latitude: 45.8038, longitude: 126.5350),
        "长春": CLLocationCoordinate2D(latitude: 43.8171, longitude: 125.3235),
        "石家庄": CLLocationCoordinate2D(latitude: 38.0428, longitude: 114.5149),
        "太原": CLLocationCoordinate2D(latitude: 37.8706, longitude: 112.5489),
        "呼和浩特": CLLocationCoordinate2D(latitude: 40.8426, longitude: 111.7492),
        "南昌": CLLocationCoordinate2D(latitude: 28.6820, longitude: 115.8579),
        "昆明": CLLocationCoordinate2D(latitude: 25.0389, longitude: 102.7183),
        "贵阳": CLLocationCoordinate2D(latitude: 26.6470, longitude: 106.6302),
        "南宁": CLLocationCoordinate2D(latitude: 22.8170, longitude: 108.3665),
        "海口": CLLocationCoordinate2D(latitude: 20.0440, longitude: 110.1999),
        "兰州": CLLocationCoordinate2D(latitude: 36.0611, longitude: 103.8343),
        "西宁": CLLocationCoordinate2D(latitude: 36.6171, longitude: 101.7782),
        "银川": CLLocationCoordinate2D(latitude: 38.4872, longitude: 106.2309),
        "乌鲁木齐": CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168),
        "唐山": CLLocationCoordinate2D(latitude: 39.6305, longitude: 118.1802),
        "秦皇岛": CLLocationCoordinate2D(latitude: 39.9354, longitude: 119.5996),
        "包头": CLLocationCoordinate2D(latitude: 40.6574, longitude: 109.8403),
        "丹东": CLLocationCoordinate2D(latitude: 40.0008, longitude: 124.3547),
        "锦州": CLLocationCoordinate2D(latitude: 41.0952, longitude: 121.1270),
        "吉林": CLLocationCoordinate2D(latitude: 43.8378, longitude: 126.5496),
        "牡丹江": CLLocationCoordinate2D(latitude: 44.5517, longitude: 129.6332),
        "徐州": CLLocationCoordinate2D(latitude: 34.2044, longitude: 117.2858),
        "扬州": CLLocationCoordinate2D(latitude: 32.3942, longitude: 119.4129),
        "温州": CLLocationCoordinate2D(latitude: 27.9939, longitude: 120.6994),
        "金华": CLLocationCoordinate2D(latitude: 29.0785, longitude: 119.6474),
        "蚌埠": CLLocationCoordinate2D(latitude: 32.9163, longitude: 117.3893),
        "安庆": CLLocationCoordinate2D(latitude: 30.5429, longitude: 117.0635),
        "泉州": CLLocationCoordinate2D(latitude: 24.8741, longitude: 118.6757),
        "九江": CLLocationCoordinate2D(latitude: 29.7051, longitude: 116.0019),
        "赣州": CLLocationCoordinate2D(latitude: 25.8311, longitude: 114.9350),
        "烟台": CLLocationCoordinate2D(latitude: 37.4638, longitude: 121.4479),
        "济宁": CLLocationCoordinate2D(latitude: 35.4147, longitude: 116.5871),
        "洛阳": CLLocationCoordinate2D(latitude: 34.6197, longitude: 112.4540),
        "平顶山": CLLocationCoordinate2D(latitude: 33.7662, longitude: 113.1927),
        "宜昌": CLLocationCoordinate2D(latitude: 30.6919, longitude: 111.2865),
        "襄阳": CLLocationCoordinate2D(latitude: 32.0089, longitude: 112.1224),
        "岳阳": CLLocationCoordinate2D(latitude: 29.3571, longitude: 113.1289),
        "常德": CLLocationCoordinate2D(latitude: 29.0316, longitude: 111.6985),
        "韶关": CLLocationCoordinate2D(latitude: 24.8104, longitude: 113.5972),
        "湛江": CLLocationCoordinate2D(latitude: 21.2707, longitude: 110.3594),
        "惠州": CLLocationCoordinate2D(latitude: 23.1115, longitude: 114.4168),
        "桂林": CLLocationCoordinate2D(latitude: 25.2742, longitude: 110.2900),
        "北海": CLLocationCoordinate2D(latitude: 21.4811, longitude: 109.1202),
        "三亚": CLLocationCoordinate2D(latitude: 18.2528, longitude: 109.5119),
        "泸州": CLLocationCoordinate2D(latitude: 28.8717, longitude: 105.4423),
        "南充": CLLocationCoordinate2D(latitude: 30.8373, longitude: 106.1107),
        "遵义": CLLocationCoordinate2D(latitude: 27.7257, longitude: 106.9274),
        "大理": CLLocationCoordinate2D(latitude: 25.6065, longitude: 100.2676)
    ]

    static func normalized(_ city: String) -> String {
        let cleanCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanCity.count > 2, cleanCity.hasSuffix("市") else {
            return cleanCity
        }
        return String(cleanCity.dropLast())
    }

    static func ordered(_ cities: [String]) -> [String] {
        let unique = Array(Set(cities))
        return unique.sorted { first, second in
            let firstRank = popularCities.firstIndex(of: first)
            let secondRank = popularCities.firstIndex(of: second)
            switch (firstRank, secondRank) {
            case let (.some(left), .some(right)):
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return first.localizedStandardCompare(second) == .orderedAscending
            }
        }
    }

    static func coordinate(for city: String?) -> CLLocationCoordinate2D {
        guard let city, let coordinate = centers[normalized(city)] else {
            return CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954)
        }
        return coordinate
    }

    static func resolveCoordinate(
        city: String,
        district: String,
        area: String,
        name: String
    ) async -> CLLocationCoordinate2D {
        let cleanCity = normalized(city)
        let fallback = coordinate(for: cleanCity)
        let query = [cleanCity, district, area, name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "待补充" }
            .joined(separator: " ")
        guard !query.isEmpty else { return fallback }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if centers[cleanCity] != nil {
            request.region = region(for: cleanCity)
        }
        guard
            let response = try? await MKLocalSearch(request: request).start(),
            let coordinate = response.mapItems.first?.placemark.coordinate
        else {
            return fallback
        }
        return coordinate
    }

    static func region(for city: String?) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate(for: city),
            span: MKCoordinateSpan(
                latitudeDelta: city == nil ? 30 : 0.45,
                longitudeDelta: city == nil ? 40 : 0.60
            )
        )
    }
}

struct BudgetProfile: Codable, Equatable {
    var totalBudget: Double = 650
    var availableCash: Double = 230
    var monthlyIncome: Double = 5.8
    var loanYears: Int = 30
    var annualRate: Double = 3.05
    var isFirstHome: Bool = true
    var maxCommuteMinutes: Int? = 45
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

struct PropertyFinding: Identifiable, Equatable {
    let title: String
    let evidence: String

    var id: String {
        "\(title)|\(evidence)"
    }
}

struct PropertyAnalysis: Equatable {
    let advantages: [PropertyFinding]
    let drawbacks: [PropertyFinding]
    let missingChecks: [PropertyFinding]
}

enum PropertyTimelineEngine {
    static func events(for listing: PropertyListing) -> [PropertyTimelineEvent] {
        let recorded = listing.timeline ?? []
        let events = recorded.isEmpty ? [discoveryEvent(for: listing)] : recorded
        return events.sorted { $0.occurredAt > $1.occurredAt }
    }

    static func priceEvents(for listing: PropertyListing) -> [PropertyTimelineEvent] {
        let priceKinds: Set<PropertyTimelineEventKind> = [
            .discovered,
            .priceChanged,
            .relisted,
            .sold
        ]
        return events(for: listing)
            .filter { priceKinds.contains($0.kind) && $0.price != nil }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    static func discoveryEvent(for listing: PropertyListing) -> PropertyTimelineEvent {
        PropertyTimelineEvent(
            id: listing.id,
            kind: .discovered,
            occurredAt: listing.visitDate,
            detail: "首次记录挂牌价 \(Int(listing.totalPrice)) 万",
            price: listing.totalPrice,
            sourceURL: listing.sourceURL
        )
    }
}

enum HousingMarketKind: String, CaseIterable, Identifiable {
    case newHome = "新房"
    case resale = "二手房"

    var id: String { rawValue }
}

enum MarketMetric: String, CaseIterable, Identifiable {
    case monthOverMonth = "环比"
    case yearOverYear = "同比"

    var id: String { rawValue }
}

enum MarketTimeRange: String, CaseIterable, Identifiable {
    case threeMonths = "3个月"
    case sixMonths = "6个月"
    case twelveMonths = "全年"

    var id: String { rawValue }

    var monthCount: Int {
        switch self {
        case .threeMonths: 3
        case .sixMonths: 6
        case .twelveMonths: 12
        }
    }
}

struct MarketIndexPoint: Identifiable, Equatable {
    let year: Int
    let month: Int
    let monthOverMonthIndex: Double
    let yearOverYearIndex: Double

    var id: String { "\(year)-\(month)" }
    var monthLabel: String { "\(month)月" }
    var monthOverMonthChange: Double { monthOverMonthIndex - 100 }
    var yearOverYearChange: Double { yearOverYearIndex - 100 }

    func change(for metric: MarketMetric) -> Double {
        metric == .monthOverMonth ? monthOverMonthChange : yearOverYearChange
    }
}

struct MarketAreaBand: Identifiable, Codable, Equatable {
    let title: String
    let monthOverMonthIndex: Double
    let yearOverYearIndex: Double

    var id: String { title }
    var monthOverMonthChange: Double { monthOverMonthIndex - 100 }
    var yearOverYearChange: Double { yearOverYearIndex - 100 }
}

struct MarketRadarReading: Equatable {
    let title: String
    let detail: String
}

struct MarketRadarSnapshot: Equatable {
    let city: String
    let period: String
    let publishedAt: String
    let sourceName: String
    let sourceURL: String
    let newHome: [MarketIndexPoint]
    let resale: [MarketIndexPoint]
    let newHomeAreaBands: [MarketAreaBand]
    let resaleAreaBands: [MarketAreaBand]

    func series(
        for kind: HousingMarketKind,
        range: MarketTimeRange = .twelveMonths
    ) -> [MarketIndexPoint] {
        let allPoints = kind == .newHome ? newHome : resale
        return Array(allPoints.suffix(range.monthCount))
    }

    func areaBands(for kind: HousingMarketKind) -> [MarketAreaBand] {
        kind == .newHome ? newHomeAreaBands : resaleAreaBands
    }

    func reading(
        for kind: HousingMarketKind,
        metric: MarketMetric = .monthOverMonth
    ) -> MarketRadarReading {
        guard let latest = series(for: kind).last else {
            return MarketRadarReading(title: "暂无数据", detail: "尚未载入可用的官方价格指数。")
        }

        let selectedChange = latest.change(for: metric)
        let title: String
        if metric == .monthOverMonth, selectedChange > 0 {
            title = "环比温和上行"
        } else if metric == .monthOverMonth, selectedChange < 0 {
            title = "环比仍在调整"
        } else if metric == .yearOverYear, selectedChange > 0 {
            title = "同比高于上年同期"
        } else if metric == .yearOverYear, selectedChange < 0 {
            title = "同比仍低于上年同期"
        } else {
            title = "\(metric.rawValue)持平"
        }

        let companionMetric: MarketMetric = metric == .monthOverMonth
            ? .yearOverYear
            : .monthOverMonth
        let companionChange = latest.change(for: companionMetric)

        return MarketRadarReading(
            title: title,
            detail: "\(period)\(city)\(kind.rawValue)价格指数\(metric.rawValue)\(selectedChange.signedPercent)，"
                + "\(companionMetric.rawValue)\(companionChange.signedPercent)。"
        )
    }

    static let shanghai = MarketRadarSnapshot(
        city: "上海",
        period: "2026 年 7 月",
        publishedAt: "2026-08-17",
        sourceName: "国家统计局 · 上海住宅销售价格指数",
        sourceURL: "https://www.stats.gov.cn/sj/zxfbhjd/202608/t20260817_1965050.html",
        newHome: [
            MarketIndexPoint(year: 2025, month: 8, monthOverMonthIndex: 100.4, yearOverYearIndex: 105.9),
            MarketIndexPoint(year: 2025, month: 9, monthOverMonthIndex: 100.3, yearOverYearIndex: 105.6),
            MarketIndexPoint(year: 2025, month: 10, monthOverMonthIndex: 100.3, yearOverYearIndex: 105.7),
            MarketIndexPoint(year: 2025, month: 11, monthOverMonthIndex: 100.1, yearOverYearIndex: 105.1),
            MarketIndexPoint(year: 2025, month: 12, monthOverMonthIndex: 100.2, yearOverYearIndex: 104.8),
            MarketIndexPoint(year: 2026, month: 1, monthOverMonthIndex: 100.0, yearOverYearIndex: 104.2),
            MarketIndexPoint(year: 2026, month: 2, monthOverMonthIndex: 100.2, yearOverYearIndex: 104.2),
            MarketIndexPoint(year: 2026, month: 3, monthOverMonthIndex: 100.3, yearOverYearIndex: 103.7),
            MarketIndexPoint(year: 2026, month: 4, monthOverMonthIndex: 100.4, yearOverYearIndex: 103.7),
            MarketIndexPoint(year: 2026, month: 5, monthOverMonthIndex: 100.2, yearOverYearIndex: 103.2),
            MarketIndexPoint(year: 2026, month: 6, monthOverMonthIndex: 100.3, yearOverYearIndex: 103.1),
            MarketIndexPoint(year: 2026, month: 7, monthOverMonthIndex: 100.2, yearOverYearIndex: 103.0)
        ],
        resale: [
            MarketIndexPoint(year: 2025, month: 8, monthOverMonthIndex: 99.0, yearOverYearIndex: 97.4),
            MarketIndexPoint(year: 2025, month: 9, monthOverMonthIndex: 99.0, yearOverYearIndex: 97.6),
            MarketIndexPoint(year: 2025, month: 10, monthOverMonthIndex: 99.1, yearOverYearIndex: 96.6),
            MarketIndexPoint(year: 2025, month: 11, monthOverMonthIndex: 99.2, yearOverYearIndex: 95.4),
            MarketIndexPoint(year: 2025, month: 12, monthOverMonthIndex: 99.4, yearOverYearIndex: 93.9),
            MarketIndexPoint(year: 2026, month: 1, monthOverMonthIndex: 99.6, yearOverYearIndex: 93.2),
            MarketIndexPoint(year: 2026, month: 2, monthOverMonthIndex: 100.2, yearOverYearIndex: 93.8),
            MarketIndexPoint(year: 2026, month: 3, monthOverMonthIndex: 100.4, yearOverYearIndex: 93.8),
            MarketIndexPoint(year: 2026, month: 4, monthOverMonthIndex: 100.7, yearOverYearIndex: 94.4),
            MarketIndexPoint(year: 2026, month: 5, monthOverMonthIndex: 100.6, yearOverYearIndex: 95.7),
            MarketIndexPoint(year: 2026, month: 6, monthOverMonthIndex: 100.4, yearOverYearIndex: 96.8),
            MarketIndexPoint(year: 2026, month: 7, monthOverMonthIndex: 100.3, yearOverYearIndex: 98.0)
        ],
        newHomeAreaBands: [
            MarketAreaBand(title: "90 平方米以下", monthOverMonthIndex: 100.0, yearOverYearIndex: 101.9),
            MarketAreaBand(title: "90 至 144 平方米", monthOverMonthIndex: 100.0, yearOverYearIndex: 101.3),
            MarketAreaBand(title: "144 平方米以上", monthOverMonthIndex: 100.4, yearOverYearIndex: 105.5)
        ],
        resaleAreaBands: [
            MarketAreaBand(title: "90 平方米以下", monthOverMonthIndex: 100.5, yearOverYearIndex: 98.3),
            MarketAreaBand(title: "90 至 144 平方米", monthOverMonthIndex: 100.0, yearOverYearIndex: 97.5),
            MarketAreaBand(title: "144 平方米以上", monthOverMonthIndex: 100.5, yearOverYearIndex: 98.0)
        ]
    )
}

struct NationalMarketRecord: Codable, Equatable {
    let year: Int
    let month: Int
    let newMonthOverMonthIndex: Double
    let newYearOverYearIndex: Double
    let resaleMonthOverMonthIndex: Double
    let resaleYearOverYearIndex: Double
    let newHomeAreaBands: [MarketAreaBand]
    let resaleAreaBands: [MarketAreaBand]
}

struct NationalMarketCity: Codable, Equatable {
    let name: String
    let records: [NationalMarketRecord]
}

struct NationalMarketSource: Codable, Equatable {
    let year: Int
    let month: Int
    let publishedAt: String
    let url: String
}

struct NationalMarketDataset: Codable, Equatable {
    let generatedAt: String
    let sourceName: String
    let cities: [NationalMarketCity]
    let sources: [NationalMarketSource]

    var cityNames: [String] {
        CityCatalog.ordered(cities.map(\.name))
    }

    var availableYears: [Int] {
        Array(Set(cities.flatMap { $0.records.map(\.year) })).sorted(by: >)
    }

    func snapshot(city name: String, year: Int) -> MarketRadarSnapshot? {
        guard let city = cities.first(where: { $0.name == name }) else { return nil }
        let records = city.records
            .filter { $0.year == year }
            .sorted {
                if $0.year == $1.year { return $0.month < $1.month }
                return $0.year < $1.year
            }
        guard let latest = records.last else { return nil }

        let source = sources.first {
            $0.year == latest.year && $0.month == latest.month
        }
        let period = records.count == 12
            ? "\(year) 年"
            : "\(year) 年 1–\(latest.month) 月"

        return MarketRadarSnapshot(
            city: name,
            period: period,
            publishedAt: source?.publishedAt ?? "待确认",
            sourceName: sourceName,
            sourceURL: source?.url ?? MarketRadarSnapshot.shanghai.sourceURL,
            newHome: records.map {
                MarketIndexPoint(
                    year: $0.year,
                    month: $0.month,
                    monthOverMonthIndex: $0.newMonthOverMonthIndex,
                    yearOverYearIndex: $0.newYearOverYearIndex
                )
            },
            resale: records.map {
                MarketIndexPoint(
                    year: $0.year,
                    month: $0.month,
                    monthOverMonthIndex: $0.resaleMonthOverMonthIndex,
                    yearOverYearIndex: $0.resaleYearOverYearIndex
                )
            },
            newHomeAreaBands: latest.newHomeAreaBands,
            resaleAreaBands: latest.resaleAreaBands
        )
    }

    static let fallback = NationalMarketDataset(
        generatedAt: "2026-08-23",
        sourceName: "国家统计局 · 70 个大中城市住宅销售价格指数",
        cities: [
            NationalMarketCity(
                name: "上海",
                records: zip(
                    MarketRadarSnapshot.shanghai.newHome,
                    MarketRadarSnapshot.shanghai.resale
                ).map { newHome, resale in
                    NationalMarketRecord(
                        year: newHome.year,
                        month: newHome.month,
                        newMonthOverMonthIndex: newHome.monthOverMonthIndex,
                        newYearOverYearIndex: newHome.yearOverYearIndex,
                        resaleMonthOverMonthIndex: resale.monthOverMonthIndex,
                        resaleYearOverYearIndex: resale.yearOverYearIndex,
                        newHomeAreaBands: newHome.month == 7
                            ? MarketRadarSnapshot.shanghai.newHomeAreaBands
                            : [],
                        resaleAreaBands: resale.month == 7
                            ? MarketRadarSnapshot.shanghai.resaleAreaBands
                            : []
                    )
                }
            )
        ],
        sources: [
            NationalMarketSource(
                year: 2026,
                month: 7,
                publishedAt: MarketRadarSnapshot.shanghai.publishedAt,
                url: MarketRadarSnapshot.shanghai.sourceURL
            )
        ]
    )
}

private final class MarketDataBundleToken {}

enum MarketDataLoader {
    static let bundled = load()

    static func load(bundle: Bundle = .main) -> NationalMarketDataset {
        let bundles = [bundle, Bundle(for: MarketDataBundleToken.self)]
        for candidate in bundles {
            guard let url = candidate.url(forResource: "MarketData", withExtension: "json") else {
                continue
            }
            if
                let data = try? Data(contentsOf: url),
                let dataset = try? JSONDecoder().decode(NationalMarketDataset.self, from: data)
            {
                return dataset
            }
        }
        return .fallback
    }
}

private extension Double {
    var signedPercent: String {
        String(format: "%+.1f%%", self)
    }
}

enum VisitEvidenceKind: String, Codable, CaseIterable, Identifiable {
    case lighting
    case noise
    case transit
    case building
    case propertyManagement
    case propertyRights
    case waterAndDamage
    case surroundings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lighting: "朝向与采光"
        case .noise: "分时段噪音"
        case .transit: "地铁与通勤"
        case .building: "楼龄与公共区域"
        case .propertyManagement: "物业与维修"
        case .propertyRights: "产权与抵押"
        case .waterAndDamage: "渗水与结构"
        case .surroundings: "夜间周边动线"
        }
    }

    var action: String {
        switch self {
        case .lighting: "记录主要朝向，并在目标时段观察自然采光"
        case .noise: "分别在关窗和开窗状态下记录道路、邻里与设备噪音"
        case .transit: "从楼栋步行到站点，并记录工作日单程时间"
        case .building: "核对建成年份，查看电梯、楼道、外墙和地下空间"
        case .propertyManagement: "询问物业费、停车费及近年公共维修记录"
        case .propertyRights: "通过正规渠道核验产权、抵押、租约及户口情况"
        case .waterAndDamage: "检查窗边、墙角、厨卫和顶层是否存在渗水痕迹"
        case .surroundings: "夜间走一次小区到交通站点及生活设施的路线"
        }
    }

    var symbol: String {
        switch self {
        case .lighting: "sun.max.fill"
        case .noise: "waveform"
        case .transit: "tram.fill"
        case .building: "building.2.fill"
        case .propertyManagement: "wrench.and.screwdriver.fill"
        case .propertyRights: "doc.text.magnifyingglass"
        case .waterAndDamage: "drop.triangle.fill"
        case .surroundings: "moon.stars.fill"
        }
    }
}

struct EvidenceItem: Identifiable, Equatable {
    let kind: VisitEvidenceKind
    let isComplete: Bool

    var id: VisitEvidenceKind { kind }
}

struct EvidenceReport: Equatable {
    let items: [EvidenceItem]

    var completedCount: Int {
        items.filter(\.isComplete).count
    }

    var totalCount: Int {
        items.count
    }

    var completionRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var reviewTasks: [EvidenceItem] {
        items.filter { !$0.isComplete }
    }
}

enum EvidenceEngine {
    static func report(for listing: PropertyListing) -> EvidenceReport {
        let verified = Set(listing.verifiedEvidence ?? [])
        let currentYear = Calendar.current.component(.year, from: .now)
        let hasValidBuildYear = listing.buildYear.map { (1900...currentYear).contains($0) } == true
        let hasNoiseEvidence = verified.contains(.noise)
            || listing.concerns.contains { $0.contains("噪音") }
            || listing.note.contains("噪音")
        let hasPropertyEvidence = verified.contains(.propertyManagement)
            || listing.tags.contains { $0.contains("物业") || $0.contains("维修") }
        let hasRightsEvidence = verified.contains(.propertyRights)
            || listing.tags.contains { $0.contains("产权") || $0.contains("抵押") }

        return EvidenceReport(
            items: [
                EvidenceItem(
                    kind: .lighting,
                    isComplete: listing.orientation != nil || verified.contains(.lighting)
                ),
                EvidenceItem(kind: .noise, isComplete: hasNoiseEvidence),
                EvidenceItem(
                    kind: .transit,
                    isComplete: (listing.metroDistanceMeters != nil && listing.commuteMinutes > 0)
                        || verified.contains(.transit)
                ),
                EvidenceItem(
                    kind: .building,
                    isComplete: hasValidBuildYear || verified.contains(.building)
                ),
                EvidenceItem(kind: .propertyManagement, isComplete: hasPropertyEvidence),
                EvidenceItem(kind: .propertyRights, isComplete: hasRightsEvidence),
                EvidenceItem(
                    kind: .waterAndDamage,
                    isComplete: verified.contains(.waterAndDamage)
                ),
                EvidenceItem(
                    kind: .surroundings,
                    isComplete: verified.contains(.surroundings)
                )
            ]
        )
    }
}

enum BuyingJourneyStage: Int, CaseIterable, Identifiable {
    case preparation
    case areaSelection
    case viewing
    case decision
    case dueDiligence
    case transaction

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .preparation: "准备"
        case .areaSelection: "选区"
        case .viewing: "看房"
        case .decision: "决策"
        case .dueDiligence: "尽调"
        case .transaction: "交割"
        }
    }

    var guidance: String {
        switch self {
        case .preparation: "先确认资格、现金边界和融资口径，避免带着错误预算看房。"
        case .areaSelection: "把关注范围收敛到两至三个板块，再比较真实通勤和供给。"
        case .viewing: "优先补齐候选房源的现场证据，不用数量代替判断。"
        case .decision: "围绕最终候选统一成本、风险和家庭意见。"
        case .dueDiligence: "在付款前逐项核验产权、税费、合同与资金安排。"
        case .transaction: "按节点留存凭证，完成贷款、过户和交房验收。"
        }
    }

    var symbol: String {
        switch self {
        case .preparation: "creditcard.fill"
        case .areaSelection: "map.fill"
        case .viewing: "eye.fill"
        case .decision: "scale.3d"
        case .dueDiligence: "doc.text.magnifyingglass"
        case .transaction: "key.fill"
        }
    }
}

enum BuyingPlanTaskKind: Equatable {
    case automatic
    case manual
}

struct BuyingPlanTask: Identifiable, Equatable {
    let id: String
    let stage: BuyingJourneyStage
    let title: String
    let detail: String
    let kind: BuyingPlanTaskKind
    let isComplete: Bool
}

struct BuyingPlanProgress: Equatable {
    let tasks: [BuyingPlanTask]
    let currentStage: BuyingJourneyStage

    var completedCount: Int {
        tasks.filter(\.isComplete).count
    }

    var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    var nextTasks: [BuyingPlanTask] {
        Array(tasks.filter { !$0.isComplete }.prefix(3))
    }

    func tasks(for stage: BuyingJourneyStage) -> [BuyingPlanTask] {
        tasks.filter { $0.stage == stage }
    }

    func isComplete(_ stage: BuyingJourneyStage) -> Bool {
        let stageTasks = tasks(for: stage)
        return !stageTasks.isEmpty && stageTasks.allSatisfy(\.isComplete)
    }
}

enum BuyingPlanEngine {
    static func progress(
        listings: [PropertyListing],
        profile: BudgetProfile,
        completedManualTaskIDs: Set<String>
    ) -> BuyingPlanProgress {
        let relevantListings = listings.filter {
            $0.status != .archived
                && $0.availability != .delisted
                && $0.availability != .sold
        }
        let budget = BudgetEngine.snapshot(for: profile)
        let areas = Set(relevantListings.map(\.area))
        let commuteTarget = profile.maxCommuteMinutes ?? 45
        let commuteMatches = relevantListings.filter {
            $0.commuteMinutes <= commuteTarget
        }.count
        let reports = relevantListings.map(EvidenceEngine.report)
        let averageEvidence = reports.isEmpty
            ? 0
            : reports.map(\.completionRatio).reduce(0, +) / Double(reports.count)
        let shortlistCount = relevantListings.filter { $0.status == .shortlisted }.count

        func manual(
            _ id: String,
            stage: BuyingJourneyStage,
            title: String,
            detail: String
        ) -> BuyingPlanTask {
            BuyingPlanTask(
                id: id,
                stage: stage,
                title: title,
                detail: detail,
                kind: .manual,
                isComplete: completedManualTaskIDs.contains(id)
            )
        }

        func automatic(
            _ id: String,
            stage: BuyingJourneyStage,
            title: String,
            detail: String,
            isComplete: Bool
        ) -> BuyingPlanTask {
            BuyingPlanTask(
                id: id,
                stage: stage,
                title: title,
                detail: detail,
                kind: .automatic,
                isComplete: isComplete
            )
        }

        var budgetIssues: [String] = []
        if budget.cashGap > 0 {
            budgetIssues.append(String(format: "现金仍缺 %.1f 万", budget.cashGap))
        }
        if budget.monthlyPaymentRatio > 0.4 {
            budgetIssues.append(
                String(
                    format: "月供占收入 %.1f%%，目标不超过 40%%",
                    budget.monthlyPaymentRatio * 100
                )
            )
        }
        let budgetDetail = budget.isComfortable
            ? "现金储备和月供压力均在当前设定范围内"
            : budgetIssues.joined(separator: "；")
        let areaDetail: String
        if areas.isEmpty {
            areaDetail = "尚未形成板块记录，先选择两至三个板块"
        } else if areas.count > 3 {
            areaDetail = "当前记录 \(areas.count) 个板块，建议收敛到两至三个"
        } else {
            areaDetail = "已聚焦 \(areas.sorted().joined(separator: "、"))"
        }

        let tasks = [
            automatic(
                "budget-boundary",
                stage: .preparation,
                title: "承受边界可执行",
                detail: budgetDetail,
                isComplete: budget.isComfortable
            ),
            manual(
                "purchase-qualification",
                stage: .preparation,
                title: "核验购房资格",
                detail: "确认限购、征信、公积金与家庭名下住房情况"
            ),
            manual(
                "financing-precheck",
                stage: .preparation,
                title: "取得银行融资口径",
                detail: "确认可贷额度、年限、利率和月供，不把平台试算当承诺"
            ),
            automatic(
                "area-shortlist",
                stage: .areaSelection,
                title: "板块收敛到两至三个",
                detail: areaDetail,
                isComplete: (2...3).contains(areas.count)
            ),
            automatic(
                "commute-screen",
                stage: .areaSelection,
                title: "通勤候选足够",
                detail: "\(commuteMatches) 套房源不超过 \(commuteTarget) 分钟通勤上限",
                isComplete: commuteMatches >= 2
            ),
            automatic(
                "structured-viewings",
                stage: .viewing,
                title: "形成结构化样本",
                detail: "已记录 \(relevantListings.count) 套有效房源，目标至少三套",
                isComplete: relevantListings.count >= 3
            ),
            automatic(
                "evidence-coverage",
                stage: .viewing,
                title: "关键证据达到六成",
                detail: "当前平均证据完整度 \(Int(averageEvidence * 100))%",
                isComplete: averageEvidence >= 0.6
            ),
            automatic(
                "revisit-completed",
                stage: .viewing,
                title: "至少完成一次复看",
                detail: "复看应优先补齐噪音、物业、渗漏和产权证据",
                isComplete: relevantListings.contains { $0.status == .revisit }
            ),
            automatic(
                "final-shortlist",
                stage: .decision,
                title: "最终候选不超过三套",
                detail: "当前有 \(shortlistCount) 套候选",
                isComplete: (1...3).contains(shortlistCount)
            ),
            manual(
                "cost-boundary",
                stage: .decision,
                title: "确认十年成本与退出边界",
                detail: "比较至少两套候选，并写下最高报价和放弃条件"
            ),
            manual(
                "family-consensus",
                stage: .decision,
                title: "家庭意见完成对齐",
                detail: "明确共同偏好、分歧和任何一方的一票否决项"
            ),
            manual(
                "ownership-check",
                stage: .dueDiligence,
                title: "完成产权与占用核验",
                detail: "核验产权人、抵押、查封、租约、户口及实际占用"
            ),
            manual(
                "tax-funds-check",
                stage: .dueDiligence,
                title: "确认税费与资金路径",
                detail: "由专业人员复核税费、付款节点和资金监管安排"
            ),
            manual(
                "contract-review",
                stage: .dueDiligence,
                title: "完成合同风险复核",
                detail: "重点确认违约责任、交房条件、附属设施和补充条款"
            ),
            manual(
                "deposit-signing",
                stage: .transaction,
                title: "定金与网签凭证归档",
                detail: "核对收款主体、付款条件，并留存全部签署文件"
            ),
            manual(
                "loan-transfer",
                stage: .transaction,
                title: "贷款、缴税与过户完成",
                detail: "按银行和交易中心节点跟踪状态并保存回执"
            ),
            manual(
                "handover",
                stage: .transaction,
                title: "交房验收与尾款完成",
                detail: "核对房屋现状、水电物业结清、钥匙和户口迁出"
            )
        ]

        let currentStage = BuyingJourneyStage.allCases.first { stage in
            let stageTasks = tasks.filter { $0.stage == stage }
            return stageTasks.contains { !$0.isComplete }
        } ?? .transaction

        return BuyingPlanProgress(tasks: tasks, currentStage: currentStage)
    }
}

struct CoupleConsensus: Equatable {
    let difference: Int
    let title: String
    let detail: String
    let needsDiscussion: Bool
}

enum CoupleDecisionEngine {
    static func evaluate(userScore: Int, partnerScore: Int) -> CoupleConsensus {
        let difference = abs(userScore - partnerScore)
        if difference <= 1 {
            return CoupleConsensus(
                difference: difference,
                title: "判断基本一致",
                detail: "双方评分接近，可以共同检查剩余证据。",
                needsDiscussion: false
            )
        }
        if difference <= 3 {
            return CoupleConsensus(
                difference: difference,
                title: "存在取舍分歧",
                detail: "先分别说明最看重和最担心的一项，再决定是否复看。",
                needsDiscussion: true
            )
        }
        return CoupleConsensus(
            difference: difference,
            title: "核心判断不同",
            detail: "暂缓推进，分别记录不可妥协项后再重新比较。",
            needsDiscussion: true
        )
    }
}

struct TenYearCostSnapshot: Equatable {
    let downPayment: Double
    let mortgagePayments: Double
    let estimatedTaxesAndFees: Double
    let estimatedRenovation: Double
    let estimatedPropertyFees: Double
    let totalCashOutflow: Double
    let commuteHours: Double
}

enum TenYearCostEngine {
    static func snapshot(
        for listing: PropertyListing,
        profile: BudgetProfile,
        years: Int = 10,
        renovationPerSquareMeter: Double = 1_500,
        monthlyPropertyFeePerSquareMeter: Double = 4
    ) -> TenYearCostSnapshot {
        var listingProfile = profile
        listingProfile.totalBudget = listing.totalPrice
        let budget = BudgetEngine.snapshot(for: listingProfile)
        let months = min(years, profile.loanYears) * 12
        let mortgagePayments = budget.monthlyPayment * Double(months)
        let renovation = listing.size * renovationPerSquareMeter / 10_000
        let propertyFees = listing.size * monthlyPropertyFeePerSquareMeter * Double(months) / 10_000
        let commuteHours = Double(listing.commuteMinutes * 2 * 240 * years) / 60

        return TenYearCostSnapshot(
            downPayment: budget.downPayment,
            mortgagePayments: mortgagePayments,
            estimatedTaxesAndFees: budget.estimatedTaxesAndFees,
            estimatedRenovation: renovation,
            estimatedPropertyFees: propertyFees,
            totalCashOutflow: budget.downPayment
                + mortgagePayments
                + budget.estimatedTaxesAndFees
                + renovation
                + propertyFees,
            commuteHours: commuteHours
        )
    }
}

enum PropertyAnalyzer {
    static func analyze(
        _ listing: PropertyListing,
        profile: BudgetProfile,
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) -> PropertyAnalysis {
        var advantages: [PropertyFinding] = []
        var drawbacks: [PropertyFinding] = []
        var missingChecks: [PropertyFinding] = []
        let verified = Set(listing.verifiedEvidence ?? [])

        let priceDifference = profile.totalBudget - listing.totalPrice
        if priceDifference >= 0 {
            advantages.append(
                PropertyFinding(
                    title: "总价在预算内",
                    evidence: "房源 \(Int(listing.totalPrice)) 万，低于预算 \(Int(priceDifference)) 万"
                )
            )
        } else {
            drawbacks.append(
                PropertyFinding(
                    title: "总价超出预算",
                    evidence: "房源 \(Int(listing.totalPrice)) 万，超出预算 \(Int(-priceDifference)) 万"
                )
            )
        }

        let commuteTarget = profile.maxCommuteMinutes ?? 45
        if listing.commuteMinutes <= commuteTarget {
            advantages.append(
                PropertyFinding(
                    title: "通勤符合预期",
                    evidence: "实测或估算 \(listing.commuteMinutes) 分钟，目标不超过 \(commuteTarget) 分钟"
                )
            )
        } else {
            drawbacks.append(
                PropertyFinding(
                    title: "通勤超过预期",
                    evidence: "实测或估算 \(listing.commuteMinutes) 分钟，比目标多 \(listing.commuteMinutes - commuteTarget) 分钟"
                )
            )
        }

        if listing.score >= 8 {
            advantages.append(
                PropertyFinding(
                    title: "现场感受较好",
                    evidence: "用户现场评分 \(listing.score)/10"
                )
            )
        } else if listing.score <= 5 {
            drawbacks.append(
                PropertyFinding(
                    title: "现场感受一般",
                    evidence: "用户现场评分 \(listing.score)/10"
                )
            )
        }

        if let orientation = listing.orientation {
            if orientation.contains("南") {
                advantages.append(
                    PropertyFinding(
                        title: "主要朝向较理想",
                        evidence: "录入朝向为 \(orientation)"
                    )
                )
            } else if orientation == "北" {
                drawbacks.append(
                    PropertyFinding(
                        title: "主要朝向受限",
                        evidence: "录入朝向为北，采光需要现场复核"
                    )
                )
            }
        } else if !verified.contains(.lighting) {
            missingChecks.append(
                PropertyFinding(title: "确认主要朝向", evidence: "尚未录入朝向与采光情况")
            )
        }

        if let distance = listing.metroDistanceMeters {
            if distance <= 800 {
                advantages.append(
                    PropertyFinding(
                        title: "地铁步行距离较近",
                        evidence: "录入距离约 \(distance) 米"
                    )
                )
            } else if distance > 1_500 {
                drawbacks.append(
                    PropertyFinding(
                        title: "地铁步行距离较远",
                        evidence: "录入距离约 \(distance) 米"
                    )
                )
            }
        } else if !verified.contains(.transit) {
            missingChecks.append(
                PropertyFinding(title: "实测地铁步行距离", evidence: "尚未记录从楼栋到站点的距离")
            )
        }

        if let buildYear = listing.buildYear, (1900...currentYear).contains(buildYear) {
            let buildingAge = max(0, currentYear - buildYear)
            if buildingAge <= 10 {
                advantages.append(
                    PropertyFinding(
                        title: "房龄较新",
                        evidence: "\(buildYear) 年建成，约 \(buildingAge) 年房龄"
                    )
                )
            } else if buildingAge >= 20 {
                drawbacks.append(
                    PropertyFinding(
                        title: "房龄偏长",
                        evidence: "\(buildYear) 年建成，约 \(buildingAge) 年房龄，需关注维护状况"
                    )
                )
            }
        } else if let buildYear = listing.buildYear {
            missingChecks.append(
                PropertyFinding(
                    title: "核对建成年份",
                    evidence: "\(buildYear) 不在 1900 至 \(currentYear) 的有效范围内"
                )
            )
        } else if !verified.contains(.building) {
            missingChecks.append(
                PropertyFinding(title: "核对建成年份", evidence: "尚未录入房龄信息")
            )
        }

        if listing.rooms == "待补充" {
            missingChecks.append(
                PropertyFinding(title: "补充户型信息", evidence: "当前户型尚未确认")
            )
        }
        if listing.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            missingChecks.append(
                PropertyFinding(title: "保留房源来源", evidence: "缺少原始链接，后续无法复查价格与描述")
            )
        }
        if !verified.contains(.propertyRights)
            && !listing.tags.contains(where: { $0.contains("产权") || $0.contains("抵押") })
        {
            missingChecks.append(
                PropertyFinding(title: "产权与抵押核验", evidence: "现有记录中没有产权或抵押证明")
            )
        }
        if !verified.contains(.propertyManagement)
            && !listing.tags.contains(where: { $0.contains("物业") || $0.contains("维修") })
        {
            missingChecks.append(
                PropertyFinding(title: "物业与维修记录", evidence: "现有记录中没有物业费或维修证据")
            )
        }
        let noiseRecorded = verified.contains(.noise)
            || listing.concerns.contains { $0.contains("噪音") }
            || listing.note.contains("噪音")
        if !noiseRecorded {
            missingChecks.append(
                PropertyFinding(title: "分时段核验噪音", evidence: "现场记录未覆盖早晚高峰与夜间噪音")
            )
        }

        return PropertyAnalysis(
            advantages: advantages,
            drawbacks: drawbacks,
            missingChecks: missingChecks
        )
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
            .max(by: { $0.value.count < $1.value.count })?.key ?? "当前城市"

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
