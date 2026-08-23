import MapKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var showAdd = false

    var body: some View {
        TabView {
            HomeView(showAdd: $showAdd)
                .tabItem { Label("今日", systemImage: "sparkles") }

            PropertyMapView()
                .tabItem { Label("地图", systemImage: "map.fill") }

            JournalView(showAdd: $showAdd)
                .tabItem { Label("看房", systemImage: "text.book.closed.fill") }

            AIAdvisorView()
                .tabItem { Label("AI", systemImage: "wand.and.stars") }

            BuyingPlanView()
                .tabItem { Label("规划", systemImage: "checklist") }
        }
        .sheet(isPresented: $showAdd) {
            AddPropertyView { listing in
                store.add(listing)
                showAdd = false
            }
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: PropertyStore
    @Binding var showAdd: Bool

    private var snapshot: BudgetSnapshot {
        BudgetEngine.snapshot(for: store.budget)
    }

    private var activeListings: [PropertyListing] {
        store.listings.filter { $0.status != .archived }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    decisionStrip
                    recentSection
                    nextAction
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(HuJuTheme.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "house.and.flag.circle.fill")
                        .font(.title)
                        .foregroundStyle(HuJuTheme.green)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("沪居")
                            .font(.title2.weight(.black))
                            .foregroundStyle(HuJuTheme.ink)
                        Text("上海看房决策日志")
                            .font(.caption)
                            .foregroundStyle(HuJuTheme.muted)
                    }
                }
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(HuJuTheme.ink)
                        .clipShape(Circle())
                }
                .accessibilityLabel("记录一次看房")
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("不是多看，\n是更会判断。")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(HuJuTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("已走访 \(Set(activeListings.map(\.area)).count) 个板块，留下 \(activeListings.count) 份现场证据")
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 14)
    }

    private var decisionStrip: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("预算脉搏")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.68))
                    Text("\(Int(store.budget.totalBudget)) 万")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("估算月供")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                    Text(String(format: "%.1f 万", snapshot.monthlyPayment))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(snapshot.isComfortable ? HuJuTheme.yellow : HuJuTheme.coral)
                        .frame(width: proxy.size.width * min(snapshot.monthlyPaymentRatio / 0.55, 1))
                }
            }
            .frame(height: 7)

            HStack {
                Label(
                    snapshot.isComfortable ? "现金流可控" : "需要收紧上限",
                    systemImage: snapshot.isComfortable ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("月供 / 收入 \(Int(snapshot.monthlyPaymentRatio * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(18)
        .background(HuJuTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var recentSection: some View {
        VStack(spacing: 12) {
            SectionHeading(eyebrow: "RECENT VISITS", title: "最近看过", action: "共 \(store.listings.count) 套")
            ForEach(store.listings.prefix(3)) { listing in
                PropertyRow(listing: listing)
            }
        }
    }

    private var nextAction: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "NEXT BEST ACTION", title: "下一步只做一件事")
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundStyle(HuJuTheme.yellow)
                    .frame(width: 46, height: 46)
                    .background(HuJuTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 4) {
                    Text("晚高峰复看 · 万科翡翠公园")
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                    Text("补齐噪音、园区照明和地铁回家动线")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(HuJuTheme.muted)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(HuJuTheme.line)
            }
        }
    }
}

private struct PropertyMapView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            span: MKCoordinateSpan(latitudeDelta: 0.34, longitudeDelta: 0.38)
        )
    )
    @State private var selectedID: UUID?

    private var selected: PropertyListing? {
        store.listings.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selectedID) {
                ForEach(store.listings) { listing in
                    Marker(
                        listing.name,
                        systemImage: listing.status == .archived ? "xmark" : "house.fill",
                        coordinate: listing.coordinate
                    )
                    .tint(markerColor(for: listing.status))
                    .tag(listing.id)
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(HuJuTheme.green)
                    Text("上海 · 看房足迹")
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                    Spacer()
                    Text("\(store.listings.count) 个位置")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.muted)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let selected {
                    mapSelection(selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    HStack(spacing: 9) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(HuJuTheme.blue)
                        Text("点选地图标记，查看你的现场结论")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HuJuTheme.ink)
                        Spacer()
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private func markerColor(for status: PropertyStatus) -> Color {
        switch status {
        case .shortlisted: HuJuTheme.green
        case .revisit: HuJuTheme.coral
        case .visited: HuJuTheme.blue
        case .archived: HuJuTheme.muted
        }
    }

    private func mapSelection(_ listing: PropertyListing) -> some View {
        HStack(spacing: 12) {
            ScoreRing(score: listing.score)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(listing.name)
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                    StatusBadge(status: listing.status)
                }
                Text("\(listing.district) · \(listing.area) · \(Int(listing.totalPrice)) 万")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                Text(listing.note)
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.ink)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct JournalView: View {
    @EnvironmentObject private var store: PropertyStore
    @Binding var showAdd: Bool
    @State private var filter: PropertyStatus?

    private var visibleListings: [PropertyListing] {
        guard let filter else { return store.listings }
        return store.listings.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterBar
                    ForEach(visibleListings) { listing in
                        NavigationLink {
                            PropertyDetailView(listing: listing)
                        } label: {
                            PropertyRow(listing: listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(HuJuTheme.paper)
            .navigationTitle("看房日志")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("记录一次看房")
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "全部", status: nil)
                ForEach(PropertyStatus.allCases) { status in
                    filterButton(title: status.rawValue, status: status)
                }
            }
        }
    }

    private func filterButton(title: String, status: PropertyStatus?) -> some View {
        Button {
            filter = status
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filter == status ? Color.white : HuJuTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(filter == status ? HuJuTheme.ink : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct PropertyDetailView: View {
    let listing: PropertyListing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StatusBadge(status: listing.status)
                        Spacer()
                        ScoreRing(score: listing.score, diameter: 52)
                    }
                    Text(listing.name)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(HuJuTheme.ink)
                    Text("\(listing.district) · \(listing.area)")
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                    HStack {
                        MetricPill(symbol: "banknote.fill", text: "\(Int(listing.totalPrice)) 万", tint: HuJuTheme.coral)
                        MetricPill(symbol: "square.split.2x2.fill", text: listing.rooms, tint: HuJuTheme.blue)
                        MetricPill(symbol: "tram.fill", text: "\(listing.commuteMinutes) min", tint: HuJuTheme.green)
                    }
                }

                Divider()

                evidenceSection(title: "现场加分", symbol: "plus.circle.fill", color: HuJuTheme.green, items: listing.highlights)
                evidenceSection(title: "风险与疑问", symbol: "exclamationmark.triangle.fill", color: HuJuTheme.coral, items: listing.concerns)

                VStack(alignment: .leading, spacing: 8) {
                    Text("当时的判断")
                        .font(.headline)
                    Text(listing.note)
                        .font(.body)
                        .foregroundStyle(HuJuTheme.muted)
                        .lineSpacing(4)
                }
            }
            .padding(18)
        }
        .background(HuJuTheme.paper)
        .navigationTitle("看房详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func evidenceSection(
        title: String,
        symbol: String,
        color: Color,
        items: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(item)
                        .foregroundStyle(HuJuTheme.ink)
                }
            }
        }
    }
}

private struct AIAdvisorView: View {
    @EnvironmentObject private var store: PropertyStore
    private let advisor = LocalAIAdvisor()

    private var recommendations: [AIRecommendation] {
        advisor.recommendations(listings: store.listings, profile: store.budget)
    }

    private var insights: [AIInsight] {
        advisor.insights(listings: store.listings, profile: store.budget)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    aiHeader

                    VStack(spacing: 10) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }

                    VStack(spacing: 12) {
                        SectionHeading(eyebrow: "EXPLAINABLE RANKING", title: "基于你的证据")
                        ForEach(Array(recommendations.prefix(3).enumerated()), id: \.element.property.id) { index, item in
                            recommendationRow(index: index, item: item)
                        }
                    }

                    Text("AI 结论来自你的预算和看房记录，不构成估价、贷款、税务或产权意见。")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(HuJuTheme.paper)
            .navigationTitle("AI 决策助手")
        }
    }

    private var aiHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.title)
                .foregroundStyle(HuJuTheme.yellow)
                .frame(width: 54, height: 54)
                .background(HuJuTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) {
                Text("我不替你做决定")
                    .font(.title2.weight(.black))
                    .foregroundStyle(HuJuTheme.ink)
                Text("我负责找出你忽略的证据、冲突和下一步。")
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
            }
            Spacer()
        }
    }

    private func insightRow(_ insight: AIInsight) -> some View {
        let color: Color = switch insight.tone {
        case .positive: HuJuTheme.green
        case .warning: HuJuTheme.coral
        case .neutral: HuJuTheme.blue
        }

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Text(insight.detail)
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(HuJuTheme.line)
        }
    }

    private func recommendationRow(index: Int, item: AIRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: "%02d", index + 1))
                    .font(.title3.monospacedDigit().weight(.black))
                    .foregroundStyle(HuJuTheme.green)
                Text(item.property.name)
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Spacer()
                Text("\(item.fitScore)")
                    .font(.title2.monospacedDigit().weight(.black))
                    .foregroundStyle(HuJuTheme.ink)
                Text("匹配")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(item.reasons.prefix(3), id: \.self) { reason in
                    Label(reason, systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !item.missingChecks.isEmpty {
                Label("待核验：" + item.missingChecks.prefix(2).joined(separator: "、"), systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.coral)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(HuJuTheme.line)
        }
    }
}

private struct BuyingPlanView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var completed = Set([0, 1])

    private let steps = [
        ("明确资格与预算", "核验限购、征信、公积金和现金储备"),
        ("建立板块短名单", "按通勤、生活和流动性选 2-3 个板块"),
        ("结构化看房", "白天、夜间、工作日分别留下证据"),
        ("产权与交易核验", "查产权、抵押、税费、户口与租约"),
        ("贷款与谈判", "取得银行口径，设置报价和退出边界"),
        ("签约至交割", "定金、网签、贷款、税费、过户与交房")
    ]

    private var snapshot: BudgetSnapshot {
        BudgetEngine.snapshot(for: store.budget)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    budgetPanel
                    checklist
                    policyNotice
                }
                .padding(16)
            }
            .background(HuJuTheme.paper)
            .navigationTitle("购房规划")
        }
    }

    private var budgetPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(eyebrow: "AFFORDABILITY", title: "预算不是一个数字")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("目标总价")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(store.budget.totalBudget)) 万")
                        .font(.title3.monospacedDigit().weight(.black))
                        .foregroundStyle(HuJuTheme.coral)
                }
                Slider(value: $store.budget.totalBudget, in: 300...1_200, step: 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("可用现金")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(store.budget.availableCash)) 万")
                        .font(.headline.monospacedDigit())
                }
                Slider(value: $store.budget.availableCash, in: 80...600, step: 10)
            }

            HStack(spacing: 0) {
                budgetMetric("首付估算", value: "\(Int(snapshot.downPayment)) 万")
                Divider().frame(height: 44)
                budgetMetric("税费预留", value: "\(Int(snapshot.estimatedTaxesAndFees)) 万")
                Divider().frame(height: 44)
                budgetMetric("月供估算", value: String(format: "%.1f 万", snapshot.monthlyPayment))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(HuJuTheme.line)
        }
    }

    private func budgetMetric(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(HuJuTheme.muted)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(HuJuTheme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var checklist: some View {
        VStack(spacing: 12) {
            SectionHeading(
                eyebrow: "BUYING JOURNEY",
                title: "从 0 到 1",
                action: "\(completed.count)/\(steps.count)"
            )

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Button {
                    if completed.contains(index) {
                        completed.remove(index)
                    } else {
                        completed.insert(index)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: completed.contains(index) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(completed.contains(index) ? HuJuTheme.green : HuJuTheme.muted)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.0)
                                .font(.headline)
                                .foregroundStyle(HuJuTheme.ink)
                            Text(step.1)
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(13)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).stroke(HuJuTheme.line)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var policyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(HuJuTheme.blue)
            Text("政策快照更新于 2026-08-23。首付、限购、公积金、税费和学区信息请在交易前向主管部门、银行及专业人士复核。")
                .font(.caption)
                .foregroundStyle(HuJuTheme.muted)
        }
        .padding(.bottom, 10)
    }
}

private struct AddPropertyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var district = "浦东新区"
    @State private var area = ""
    @State private var totalPrice = 600.0
    @State private var size = 80.0
    @State private var score = 8.0
    @State private var note = ""

    let onSave: (PropertyListing) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("楼盘位置") {
                    TextField("楼盘或小区名", text: $name)
                    Picker("行政区", selection: $district) {
                        ForEach(["浦东新区", "闵行区", "徐汇区", "杨浦区", "宝山区", "嘉定区", "松江区"], id: \.self) {
                            Text($0)
                        }
                    }
                    TextField("板块", text: $area)
                }

                Section("现场数据") {
                    LabeledContent("总价", value: "\(Int(totalPrice)) 万")
                    Slider(value: $totalPrice, in: 200...1_500, step: 10)
                    LabeledContent("面积", value: "\(Int(size)) m²")
                    Slider(value: $size, in: 30...200, step: 1)
                    LabeledContent("现场评分", value: "\(Int(score))/10")
                    Slider(value: $score, in: 1...10, step: 1)
                }

                Section("第一判断") {
                    TextField("把最真实的感受留下来", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("记录一次看房")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        onSave(
            PropertyListing(
                id: UUID(),
                name: name,
                district: district,
                area: area.isEmpty ? "待补充" : area,
                latitude: 31.2304,
                longitude: 121.4737,
                totalPrice: totalPrice,
                unitPrice: Int(totalPrice * 10_000 / size),
                size: size,
                rooms: "待补充",
                visitDate: .now,
                status: .visited,
                score: Int(score),
                commuteMinutes: 45,
                tags: [],
                highlights: [],
                concerns: [],
                note: note.isEmpty ? "刚刚完成现场看房，待补充证据。" : note
            )
        )
    }
}
