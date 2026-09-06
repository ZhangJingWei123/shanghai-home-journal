import Charts
import MapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum AppTab: Hashable {
    case home
    case map
    case journal
    case ai
    case radar
}

struct RootView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var showAdd = false
    @State private var selectedTab: AppTab

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: AppTab = if arguments.contains("-showMap") {
            .map
        } else if arguments.contains("-showJournal") {
            .journal
        } else if arguments.contains("-showAI") {
            .ai
        } else if arguments.contains("-showRadar") {
            .radar
        } else {
            .home
        }
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showAdd: $showAdd)
                .tabItem { Label("今日", systemImage: "house.fill") }
                .tag(AppTab.home)

            PropertyMapView()
                .tabItem { Label("足迹", systemImage: "map.fill") }
                .tag(AppTab.map)

            JournalView(showAdd: $showAdd)
                .tabItem { Label("房源", systemImage: "list.bullet.rectangle.portrait.fill") }
                .tag(AppTab.journal)

            AIAdvisorView()
                .tabItem { Label("判断", systemImage: "checkmark.seal.fill") }
                .tag(AppTab.ai)

            BuyingPlanView()
                .tabItem { Label("市场", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.radar)
        }
        .toolbarBackground(.thinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $showAdd) {
            AddPropertyView(profile: store.budget) { listing in
                store.add(listing)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HuJuTheme.paper)
    }

    private var decisionTools: some View {
        VStack(spacing: 10) {
            SectionHeading(eyebrow: "决策工具", title: "减少判断偏差")

            NavigationLink {
                BlindComparisonView()
            } label: {
                toolRow(
                    title: "盲选对比",
                    detail: "隐藏楼盘名后，只比较预算、通勤和证据",
                    symbol: "rectangle.on.rectangle.slash.fill",
                    color: HuJuTheme.blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CoupleReviewView()
            } label: {
                toolRow(
                    title: "双人模式",
                    detail: "独立评分后再揭晓共同判断与分歧",
                    symbol: "person.2.fill",
                    color: HuJuTheme.coral
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func toolRow(title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(HuJuTheme.muted)
        }
        .padding(13)
        .hujuCard()
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: PropertyStore
    @EnvironmentObject private var authentication: AuthenticationStore
    @Binding var showAdd: Bool
    @State private var showAccount = false
    @State private var showBudgetEditor = false

    private var snapshot: BudgetSnapshot {
        BudgetEngine.snapshot(for: store.budget)
    }

    private var budgetStatus: (text: String, symbol: String, color: Color) {
        if snapshot.cashGap > 0 {
            return ("可用现金不足", "exclamationmark.circle.fill", HuJuTheme.coral)
        }
        if snapshot.monthlyPaymentRatio > 0.4 {
            return ("月供占收入偏高", "exclamationmark.circle.fill", HuJuTheme.coral)
        }
        return ("预算条件已满足", "checkmark.circle.fill", HuJuTheme.green)
    }

    private var activeListings: [PropertyListing] {
        store.listings.filter { $0.status != .archived }
    }

    private var viewingJourneyMessage: String {
        let areaCount = Set(activeListings.map(\.area)).count
        switch activeListings.count {
        case 0:
            return "从第一次实地看房开始，慢慢找清真正想要的家。"
        case 1:
            return "第一套房已经认真看过，家的样子正在变得清晰。"
        default:
            return "走过 \(areaCount) 个板块，离理想的家又近了一点。"
        }
    }

    private var nextReview: (listing: PropertyListing, task: EvidenceItem)? {
        activeListings
            .compactMap { listing in
                EvidenceEngine.report(for: listing).reviewTasks.first.map { (listing, $0) }
            }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if store.isUsingSampleData {
                        sampleDataBanner
                    }
                    if store.listings.isEmpty {
                        emptyWorkspace
                        decisionStrip
                    } else {
                        nextAction
                        decisionStrip
                        recentSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(HuJuTheme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBudgetEditor) {
                BudgetEditorView(profile: store.budget) { profile in
                    store.budget = profile
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("沪居")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(HuJuTheme.green)
                    Text("你好，\(authentication.currentUser?.displayName ?? "看房人")")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                }
                Spacer()
                Button {
                    showAccount = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(HuJuTheme.green)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("个人与隐私")
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(HuJuTheme.green)
                        .clipShape(Circle())
                }
                .accessibilityLabel("记录一次看房")
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
                    .environmentObject(authentication)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("今天的看房计划")
                    .font(.title.weight(.bold))
                    .foregroundStyle(HuJuTheme.ink)
                Text(viewingJourneyMessage)
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 14)
    }

    private var sampleDataBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "testtube.2")
                .font(.headline)
                .foregroundStyle(HuJuTheme.blue)
                .frame(width: 36, height: 36)
                .background(HuJuTheme.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text("当前为演示数据")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HuJuTheme.ink)
                Text("小区、价格和记录仅用于体验功能")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
            }
            Spacer()
            Button("清除") {
                store.deleteAllUserData()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(HuJuTheme.coral)
        }
        .padding(14)
        .background(HuJuTheme.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(HuJuTheme.blue.opacity(0.16))
        }
    }

    private var emptyWorkspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "house.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(HuJuTheme.green)

            VStack(alignment: .leading, spacing: 6) {
                Text("记录第一套房")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(HuJuTheme.ink)
                Text("先记下预算、通勤和现场观察，再决定是否加入候选。")
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
            }

            Button {
                showAdd = true
            } label: {
                Label("开始记录", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(HuJuTheme.green)

            Button {
                store.loadSampleData()
            } label: {
                Label("载入演示数据", systemImage: "testtube.2")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(HuJuTheme.blue)
        }
        .padding(18)
        .hujuCard()
    }

    private var decisionStrip: some View {
        Button {
            showBudgetEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("总价上限")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HuJuTheme.muted)
                        Text("\(Int(store.budget.totalBudget)) 万")
                            .font(.title2.monospacedDigit().weight(.bold))
                            .foregroundStyle(HuJuTheme.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("估算月供")
                            .font(.caption)
                            .foregroundStyle(HuJuTheme.muted)
                        Text(String(format: "%.1f 万", snapshot.monthlyPayment))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(HuJuTheme.ink)
                    }
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HuJuTheme.muted)
                        .frame(width: 28, height: 28)
                        .background(HuJuTheme.surfaceMuted)
                        .clipShape(Circle())
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(HuJuTheme.surfaceMuted)
                        Capsule()
                            .fill(snapshot.isComfortable ? HuJuTheme.green : HuJuTheme.coral)
                            .frame(width: proxy.size.width * min(snapshot.monthlyPaymentRatio / 0.55, 1))
                    }
                }
                .frame(height: 7)

                HStack {
                    Label(
                        budgetStatus.text,
                        systemImage: budgetStatus.symbol
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(budgetStatus.color)
                    Spacer()
                    Text(String(format: "月供占收入 %.1f%%", snapshot.monthlyPaymentRatio * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(HuJuTheme.muted)
                }
            }
            .padding(16)
            .background(HuJuTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑购房预算")
    }

    private var recentSection: some View {
        VStack(spacing: 12) {
            SectionHeading(eyebrow: "房源", title: "最近看过", action: "共 \(store.listings.count) 套")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(store.listings.prefix(4)) { listing in
                        NavigationLink {
                            PropertyDetailView(listing: listing)
                        } label: {
                            PropertyRow(listing: listing)
                                .frame(width: 286)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 3)
            }
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
    }

    private var nextAction: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "待处理", title: "下一项")

            Group {
                if let nextReview {
                    NavigationLink {
                        PropertyDetailView(listing: nextReview.listing)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: nextReview.task.kind.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(HuJuTheme.coral)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(nextReview.task.kind.title) · \(nextReview.listing.name)")
                                    .font(.headline)
                                    .foregroundStyle(HuJuTheme.ink)
                                Text(nextReview.task.kind.action)
                                    .font(.caption)
                                    .foregroundStyle(HuJuTheme.muted)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HuJuTheme.muted)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("当前候选的核心证据已补齐", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.green)
                }
            }
            .padding(16)
            .background(HuJuTheme.coral.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BudgetProfile

    let onSave: (BudgetProfile) -> Void

    init(profile: BudgetProfile, onSave: @escaping (BudgetProfile) -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
    }

    private var canSave: Bool {
        draft.totalBudget > 0
            && draft.availableCash >= 0
            && draft.monthlyIncome > 0
            && (1...180).contains(draft.maxCommuteMinutes ?? 45)
            && draft.loanYears > 0
            && draft.annualRate >= 0
    }

    private var estimate: BudgetSnapshot {
        BudgetEngine.snapshot(for: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("预算与收入") {
                    amountField("总价上限", value: $draft.totalBudget)
                    amountField("可用现金", value: $draft.availableCash)
                    amountField("家庭月收入", value: $draft.monthlyIncome)
                    HStack {
                        Text("单程通勤上限")
                        Spacer()
                        TextField(
                            "分钟",
                            value: Binding(
                                get: { draft.maxCommuteMinutes ?? 45 },
                                set: { draft.maxCommuteMinutes = $0 }
                            ),
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        Text("分钟")
                            .foregroundStyle(HuJuTheme.muted)
                    }
                }

                Section("贷款假设") {
                    Picker("贷款年限", selection: $draft.loanYears) {
                        ForEach([10, 15, 20, 25, 30], id: \.self) { years in
                            Text("\(years) 年").tag(years)
                        }
                    }
                    HStack {
                        Text("年利率")
                        Spacer()
                        TextField(
                            "利率",
                            value: $draft.annualRate,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 88)
                        Text("%")
                            .foregroundStyle(HuJuTheme.muted)
                    }
                    Toggle("首套住房", isOn: $draft.isFirstHome)
                }

                Section {
                    LabeledContent(
                        "首付",
                        value: "\(Int(estimate.downPayment)) 万元"
                    )
                    LabeledContent(
                        "月供",
                        value: String(format: "%.1f 万元", estimate.monthlyPayment)
                    )
                    LabeledContent(
                        "月供占收入",
                        value: "\(Int(estimate.monthlyPaymentRatio * 100))%"
                    )
                } header: {
                    Text("按当前设置估算")
                } footer: {
                    Text("以上为规划估算，实际贷款与税费以银行和交易环节为准。")
                }
            }
            .navigationTitle("编辑购房预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func amountField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                "金额",
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
            Text("万元")
                .foregroundStyle(HuJuTheme.muted)
        }
    }
}

private struct PropertyMapView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            span: MKCoordinateSpan(latitudeDelta: 0.34, longitudeDelta: 0.50)
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
                .shadow(color: HuJuTheme.shadow, radius: 10, x: 0, y: 4)

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
        .padding(16)
        .hujuCard()
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct JournalView: View {
    @EnvironmentObject private var store: PropertyStore
    @Binding var showAdd: Bool
    @State private var filter: PropertyStatus?
    @State private var showFieldMode = false

    private var visibleListings: [PropertyListing] {
        guard let filter else { return store.listings }
        return store.listings.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterBar

                    VStack(spacing: 0) {
                        ForEach(Array(visibleListings.enumerated()), id: \.element.id) { index, listing in
                            NavigationLink {
                                PropertyDetailView(listing: listing)
                            } label: {
                                PropertyListRow(listing: listing)
                            }
                            .buttonStyle(.plain)

                            if index < visibleListings.count - 1 {
                                Divider().padding(.leading, 89)
                            }
                        }
                    }
                    .background(HuJuTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(16)
            }
            .background(HuJuTheme.paper)
            .navigationTitle("房源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showFieldMode = true
                    } label: {
                        Image(systemName: "location.viewfinder")
                    }
                    .accessibilityLabel("进入现场模式")

                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("记录一次看房")
                }
            }
            .sheet(isPresented: $showFieldMode) {
                FieldVisitView()
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
            withAnimation(.easeInOut(duration: 0.2)) {
                filter = status
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filter == status ? Color.white : HuJuTheme.muted)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(filter == status ? HuJuTheme.green : HuJuTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct PropertyDetailView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var showEditor = false
    let listing: PropertyListing

    private var currentListing: PropertyListing {
        store.listings.first(where: { $0.id == listing.id }) ?? listing
    }

    private var analysis: PropertyAnalysis {
        PropertyAnalyzer.analyze(currentListing, profile: store.budget)
    }

    private var evidenceReport: EvidenceReport {
        EvidenceEngine.report(for: currentListing)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PropertyEvidenceVisual(listing: currentListing, height: 210)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StatusBadge(status: currentListing.status)
                        Spacer()
                        ScoreRing(score: currentListing.score, diameter: 52)
                    }
                    Text(currentListing.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text(currentListing.resolvedUnitLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text(currentListing.locationSummary)
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                    HStack {
                        MetricPill(symbol: "banknote.fill", text: "\(Int(currentListing.totalPrice)) 万")
                        MetricPill(symbol: "square.split.2x2.fill", text: currentListing.rooms)
                        MetricPill(symbol: "tram.fill", text: "\(currentListing.commuteMinutes) 分钟", tint: HuJuTheme.blue)
                    }
                }

                Divider()

                nextTaskSummary
                mediaSection
                detailNavigation

                VStack(alignment: .leading, spacing: 8) {
                    Text("当时的判断")
                        .font(.headline)
                    Text(currentListing.note)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("编辑房源")
            }
        }
        .sheet(isPresented: $showEditor) {
            PropertyEditView(listing: currentListing) { updated in
                store.update(updated)
            }
        }
    }

    private var nextTaskSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "下一步", title: "下次看房重点")
            if let task = evidenceReport.reviewTasks.first {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: task.kind.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HuJuTheme.coral)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.kind.title)
                            .font(.headline)
                            .foregroundStyle(HuJuTheme.ink)
                        Text(task.kind.action)
                            .font(.caption)
                            .foregroundStyle(HuJuTheme.muted)
                    }
                    Spacer()
                }
                .padding(14)
                .background(HuJuTheme.coral.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Label("当前核心证据已补齐", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.green)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hujuCard()
            }
        }
    }

    private var detailNavigation: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "房源资料", title: "按需查看")

            VStack(spacing: 0) {
                NavigationLink {
                    PropertyTimelineView(listingID: currentListing.id)
                } label: {
                    detailLinkRow(
                        title: "挂牌与状态记录",
                        detail: "\(PropertyTimelineEngine.events(for: currentListing).count) 条变化",
                        symbol: "clock.arrow.circlepath",
                        color: HuJuTheme.blue
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 54)

                NavigationLink {
                    PropertyAnalysisDetailView(listingID: currentListing.id)
                } label: {
                    detailLinkRow(
                        title: "优点、短板与待核验",
                        detail: "\(analysis.advantages.count) 项符合 · \(analysis.drawbacks.count) 项短板 · \(analysis.missingChecks.count) 项待核验",
                        symbol: "list.bullet.clipboard.fill",
                        color: HuJuTheme.coral
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 54)

                NavigationLink {
                    PropertyEvidenceDetailView(listingID: currentListing.id)
                } label: {
                    detailLinkRow(
                        title: "现场核验清单",
                        detail: "已完成 \(evidenceReport.completedCount)/\(evidenceReport.totalCount)",
                        symbol: "checklist.checked",
                        color: HuJuTheme.green
                    )
                }
                .buttonStyle(.plain)
            }
            .hujuCard()
        }
    }

    private func detailLinkRow(
        title: String,
        detail: String,
        symbol: String,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(HuJuTheme.muted)
        }
        .padding(14)
    }

    private var mediaSection: some View {
        let attachments = currentListing.mediaAttachments ?? []

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeading(
                eyebrow: "现场影像",
                title: "照片与视频",
                action: "\(attachments.count) 项"
            )
            PropertyMediaCaptureControls(attachments: attachments) { attachment in
                store.addMediaAttachment(attachment, for: currentListing.id)
            }
        }
    }

    private var timelinePreview: some View {
        let events = PropertyTimelineEngine.events(for: currentListing)

        return VStack(spacing: 10) {
            SectionHeading(
                eyebrow: "房源动态",
                title: "房源时间线",
                action: "\(events.count) 条"
            )
            NavigationLink {
                PropertyTimelineView(listingID: currentListing.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: events.first?.kind.symbol ?? "clock.fill")
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.blue)
                        .frame(width: 38, height: 38)
                        .background(HuJuTheme.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(events.first?.kind.title ?? "首次记录")
                            .font(.headline)
                            .foregroundStyle(HuJuTheme.ink)
                        Text(events.first?.detail ?? "查看房源历史")
                            .font(.caption)
                            .foregroundStyle(HuJuTheme.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(HuJuTheme.muted)
                }
                .padding(13)
                .hujuCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var evidenceProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("证据完整度", systemImage: "checklist.checked")
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Spacer()
                Text("\(evidenceReport.completedCount)/\(evidenceReport.totalCount)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(HuJuTheme.green)
            }
            ProgressView(value: evidenceReport.completionRatio)
                .tint(HuJuTheme.green)
            Text("完整度反映已记录或已核验的事实，不代表房源质量。")
                .font(.caption)
                .foregroundStyle(HuJuTheme.muted)
        }
        .padding(14)
        .hujuCard()
    }

    private var reviewTasks: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(
                eyebrow: "复看任务",
                title: "下次复看",
                action: "\(evidenceReport.reviewTasks.count) 项"
            )
            ForEach(evidenceReport.reviewTasks.prefix(3)) { task in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: task.kind.symbol)
                        .foregroundStyle(HuJuTheme.coral)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.kind.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HuJuTheme.ink)
                        Text(task.kind.action)
                            .font(.caption)
                            .foregroundStyle(HuJuTheme.muted)
                    }
                }
            }
        }
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

private struct PropertyAnalysisDetailView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var showEditor = false
    let listingID: UUID

    private var listing: PropertyListing? {
        store.listings.first { $0.id == listingID }
    }

    var body: some View {
        ScrollView {
            if let listing {
                VStack(alignment: .leading, spacing: 20) {
                    userNotesSection(for: listing)
                    PropertyAnalysisSections(
                        analysis: PropertyAnalyzer.analyze(listing, profile: store.budget)
                    )
                }
                .padding(16)
            } else {
                ContentUnavailableView("房源不存在", systemImage: "house.slash")
            }
        }
        .background(HuJuTheme.paper)
        .navigationTitle("房源分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("编辑我的优缺点")
                .disabled(listing == nil)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let listing {
                PropertyOpinionEditorView(listing: listing) { updated in
                    store.update(updated)
                }
            }
        }
    }

    private func userNotesSection(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "我的记录", title: "个人优缺点")
            opinionGroup(
                title: "我看中的地方",
                symbol: "hand.thumbsup.fill",
                color: HuJuTheme.green,
                items: listing.highlights
            )
            opinionGroup(
                title: "我担心的问题",
                symbol: "exclamationmark.bubble.fill",
                color: HuJuTheme.coral,
                items: listing.concerns
            )
        }
    }

    private func opinionGroup(
        title: String,
        symbol: String,
        color: Color,
        items: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(color)
            if items.isEmpty {
                Text("尚未记录")
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
            } else {
                ForEach(items, id: \.self) { item in
                    Text("· \(item)")
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.ink)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hujuCard()
    }
}

private struct PropertyOpinionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var highlights: [String]
    @State private var concerns: [String]
    @State private var note: String

    let listing: PropertyListing
    let onSave: (PropertyListing) -> Void

    init(listing: PropertyListing, onSave: @escaping (PropertyListing) -> Void) {
        self.listing = listing
        self.onSave = onSave
        _highlights = State(initialValue: listing.highlights)
        _concerns = State(initialValue: listing.concerns)
        _note = State(initialValue: listing.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                editableSection(
                    title: "我看中的地方",
                    placeholder: "例如：客厅采光稳定",
                    items: $highlights
                )
                editableSection(
                    title: "我担心的问题",
                    placeholder: "例如：晚高峰噪音待确认",
                    items: $concerns
                )
                Section("总体判断") {
                    TextField("写下你的现场感受", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HuJuTheme.paper)
            .navigationTitle("编辑个人判断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = listing
                        updated.highlights = cleaned(highlights)
                        updated.concerns = cleaned(concerns)
                        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private func editableSection(
        title: String,
        placeholder: String,
        items: Binding<[String]>
    ) -> some View {
        Section {
            ForEach(items.wrappedValue.indices, id: \.self) { index in
                HStack {
                    TextField(
                        placeholder,
                        text: Binding(
                            get: { items.wrappedValue[index] },
                            set: { items.wrappedValue[index] = $0 }
                        )
                    )
                    Button(role: .destructive) {
                        guard items.wrappedValue.indices.contains(index) else { return }
                        items.wrappedValue.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("删除")
                }
            }
            Button {
                items.wrappedValue.append("")
            } label: {
                Label("添加一项", systemImage: "plus.circle.fill")
            }
        } header: {
            Text(title)
        }
    }

    private func cleaned(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted else { return nil }
            return value
        }
    }
}

private struct PropertyEvidenceDetailView: View {
    @EnvironmentObject private var store: PropertyStore
    let listingID: UUID

    private var listing: PropertyListing? {
        store.listings.first { $0.id == listingID }
    }

    var body: some View {
        ScrollView {
            if let listing {
                let report = EvidenceEngine.report(for: listing)
                VStack(spacing: 12) {
                    HStack {
                        Text("已完成 \(report.completedCount)/\(report.totalCount)")
                            .font(.headline)
                            .foregroundStyle(HuJuTheme.ink)
                        Spacer()
                        Text("\(Int(report.completionRatio * 100))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(HuJuTheme.green)
                    }
                    ProgressView(value: report.completionRatio)
                        .tint(HuJuTheme.green)

                    ForEach(report.items) { item in
                        let isVerified = listing.verifiedEvidence?.contains(item.kind) == true
                        Button {
                            store.setEvidence(item.kind, completed: !isVerified, for: listing.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isComplete ? HuJuTheme.green : HuJuTheme.muted)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.kind.title)
                                        .font(.headline)
                                        .foregroundStyle(HuJuTheme.ink)
                                    Text(item.kind.action)
                                        .font(.caption)
                                        .foregroundStyle(HuJuTheme.muted)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                            }
                            .padding(13)
                            .hujuCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            } else {
                ContentUnavailableView("房源不存在", systemImage: "house.slash")
            }
        }
        .background(HuJuTheme.paper)
        .navigationTitle("现场核验")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PropertyEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PropertyListing

    let onSave: (PropertyListing) -> Void

    init(listing: PropertyListing, onSave: @escaping (PropertyListing) -> Void) {
        _draft = State(initialValue: listing)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.totalPrice > 0
            && draft.size > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("房源信息") {
                    TextField("楼盘或小区名", text: $draft.name)
                    TextField("房源标签", text: optionalText(\.unitLabel))
                    TextField("行政区", text: $draft.district)
                    TextField("板块", text: $draft.area)
                    TextField("楼栋", text: optionalText(\.building))
                    TextField("楼层", text: optionalText(\.floorDescription))
                    Picker("状态", selection: $draft.status) {
                        ForEach(PropertyStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("户型", text: $draft.rooms)
                }

                Section("价格与面积") {
                    numberField("总价", value: $draft.totalPrice, unit: "万元")
                    numberField("面积", value: $draft.size, unit: "平方米")
                }

                Section("现场记录") {
                    Stepper(
                        "通勤约 \(draft.commuteMinutes) 分钟",
                        value: $draft.commuteMinutes,
                        in: 5...180,
                        step: 5
                    )
                    Stepper(
                        "现场评分 \(draft.score) 分",
                        value: $draft.score,
                        in: 1...10
                    )
                    TextField("现场判断", text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                    TextField(
                        "房源来源（选填）",
                        text: Binding(
                            get: { draft.sourceURL ?? "" },
                            set: { draft.sourceURL = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                }
            }
            .navigationTitle("编辑房源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.unitPrice = Int(draft.totalPrice * 10_000 / draft.size)
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func numberField(
        _ title: String,
        value: Binding<Double>,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                title,
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
            Text(unit)
                .foregroundStyle(HuJuTheme.muted)
        }
    }

    private func optionalText(
        _ keyPath: WritableKeyPath<PropertyListing, String?>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { value in
                let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = cleanValue.isEmpty ? nil : cleanValue
            }
        )
    }
}

private struct PropertyTimelineView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var showUpdate = false
    let listingID: UUID

    private var listing: PropertyListing? {
        store.listings.first { $0.id == listingID }
    }

    var body: some View {
        ScrollView {
            if let listing {
                VStack(alignment: .leading, spacing: 20) {
                    timelineHeader(for: listing)

                    let priceEvents = PropertyTimelineEngine.priceEvents(for: listing)
                    if priceEvents.count >= 2 {
                        priceChart(priceEvents)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(
                            eyebrow: "变化记录",
                            title: "全部变化",
                            action: "\(PropertyTimelineEngine.events(for: listing).count) 条"
                        )
                        ForEach(PropertyTimelineEngine.events(for: listing)) { event in
                            timelineRow(event)
                        }
                    }
                }
                .padding(16)
            } else {
                ContentUnavailableView("房源不存在", systemImage: "house.slash")
            }
        }
        .background(HuJuTheme.paper)
        .navigationTitle("房源时间线")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showUpdate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("记录房源变化")
                .disabled(listing == nil)
            }
        }
        .sheet(isPresented: $showUpdate) {
            if let listing {
                TimelineUpdateView(listing: listing)
            }
        }
    }

    private func timelineHeader(for listing: PropertyListing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(listing.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text("\(listing.district) · \(listing.area)")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                }
                Spacer()
                Text((listing.availability ?? .active).rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HuJuTheme.green)
            }
            Text("\(Int(listing.totalPrice)) 万")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(HuJuTheme.ink)
            if let source = listing.sourceURL, let url = URL(string: source) {
                Link(destination: url) {
                    Label("查看当前来源", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .hujuCard()
    }

    private func priceChart(_ events: [PropertyTimelineEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "挂牌价格", title: "挂牌价格轨迹")
            Chart(events) { event in
                if let price = event.price {
                    LineMark(
                        x: .value("时间", event.occurredAt),
                        y: .value("价格", price)
                    )
                    .foregroundStyle(HuJuTheme.coral)
                    PointMark(
                        x: .value("时间", event.occurredAt),
                        y: .value("价格", price)
                    )
                    .foregroundStyle(HuJuTheme.coral)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 170)
        }
        .padding(14)
        .hujuCard()
    }

    private func timelineRow(_ event: PropertyTimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.symbol)
                .font(.headline)
                .foregroundStyle(color(for: event.kind))
                .frame(width: 36, height: 36)
                .background(color(for: event.kind).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.kind.title)
                        .font(.headline)
                        .foregroundStyle(HuJuTheme.ink)
                    Spacer()
                    Text(event.occurredAt.formatted(date: .numeric, time: .omitted))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(HuJuTheme.muted)
                }
                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = event.sourceURL, let url = URL(string: source) {
                    Link(destination: url) {
                        Label("打开当时来源", systemImage: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HuJuTheme.blue)
                    }
                }
            }
        }
        .padding(13)
        .hujuCard()
    }

    private func color(for kind: PropertyTimelineEventKind) -> Color {
        switch kind {
        case .discovered, .sourceUpdated: HuJuTheme.blue
        case .priceChanged: HuJuTheme.coral
        case .revisited, .relisted: HuJuTheme.green
        case .delisted: HuJuTheme.muted
        case .sold: HuJuTheme.yellow
        }
    }
}

private struct TimelineUpdateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PropertyStore
    @State private var kind = PropertyTimelineEventKind.priceChanged
    @State private var price: Double
    @State private var sourceURL: String
    @State private var note = ""
    @State private var occurredAt = Date.now

    let listing: PropertyListing

    init(listing: PropertyListing) {
        self.listing = listing
        _price = State(initialValue: listing.totalPrice)
        _sourceURL = State(initialValue: listing.sourceURL ?? "")
    }

    private var eventKinds: [PropertyTimelineEventKind] {
        [.priceChanged, .sourceUpdated, .revisited, .delisted, .relisted, .sold]
    }

    private var canSave: Bool {
        switch kind {
        case .priceChanged:
            price > 0 && price != listing.totalPrice
        case .sourceUpdated:
            !sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .discovered:
            false
        case .revisited, .delisted, .relisted, .sold:
            true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("变化类型") {
                    Picker("类型", selection: $kind) {
                        ForEach(eventKinds) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                }

                if kind == .priceChanged || kind == .relisted || kind == .sold {
                    Section("价格") {
                        TextField("挂牌或成交总价（万元）", value: $price, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                if kind == .sourceUpdated {
                    Section("房源来源") {
                        TextField("粘贴新的房源链接", text: $sourceURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                }

                Section("记录") {
                    DatePicker("发生时间", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("补充备注（选填）", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HuJuTheme.paper)
            .navigationTitle("记录变化")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let didSave = store.recordTimelineEvent(
            kind,
            for: listing.id,
            price: kind == .priceChanged || kind == .relisted || kind == .sold ? price : nil,
            sourceURL: kind == .sourceUpdated ? sourceURL : nil,
            note: note,
            occurredAt: occurredAt
        )
        if didSave {
            dismiss()
        }
    }
}

private struct PropertyAnalysisSections: View {
    let analysis: PropertyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(eyebrow: "基于房源事实", title: "自动整理")

            findingSection(
                title: "符合需求",
                symbol: "checkmark.circle.fill",
                color: HuJuTheme.green,
                findings: analysis.advantages
            )
            findingSection(
                title: "明显短板",
                symbol: "exclamationmark.triangle.fill",
                color: HuJuTheme.coral,
                findings: analysis.drawbacks,
                emptyText: "基于当前已录入信息，未发现明显短板"
            )
            findingSection(
                title: "待核验",
                symbol: "questionmark.circle.fill",
                color: HuJuTheme.blue,
                findings: analysis.missingChecks
            )
        }
    }

    private func findingSection(
        title: String,
        symbol: String,
        color: Color,
        findings: [PropertyFinding],
        emptyText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(color)

            if findings.isEmpty, let emptyText {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
            } else {
                ForEach(findings) { finding in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(finding.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(HuJuTheme.ink)
                            Text(finding.evidence)
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hujuCard()
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

                    VStack(spacing: 0) {
                        ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                            insightRow(insight)
                            if index < insights.count - 1 {
                                Divider().padding(.leading, 58)
                            }
                        }
                    }
                    .hujuCard()

                    decisionTools

                    VStack(spacing: 12) {
                        SectionHeading(eyebrow: "证据排序", title: "基于你的证据")
                        ForEach(Array(recommendations.prefix(3).enumerated()), id: \.element.property.id) { index, item in
                            recommendationRow(index: index, item: item)
                        }
                    }

                    Text("智能结论来自你的预算和看房记录，不构成估价、贷款、税务或产权意见。")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(HuJuTheme.paper)
            .navigationTitle("判断")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var decisionTools: some View {
        VStack(spacing: 10) {
            SectionHeading(eyebrow: "决策工具", title: "减少判断偏差")

            VStack(spacing: 0) {
                NavigationLink {
                    BlindComparisonView()
                } label: {
                    toolRow(
                        title: "盲选对比",
                        detail: "隐藏楼盘名后，只比较预算、通勤和证据",
                        symbol: "rectangle.on.rectangle.slash.fill",
                        color: HuJuTheme.blue
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 58)

                NavigationLink {
                    CoupleReviewView()
                } label: {
                    toolRow(
                        title: "双人模式",
                        detail: "独立评分后再揭晓共同判断与分歧",
                        symbol: "person.2.fill",
                        color: HuJuTheme.coral
                    )
                }
                .buttonStyle(.plain)
            }
            .hujuCard()
        }
    }

    private func toolRow(title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(HuJuTheme.muted)
        }
        .padding(14)
    }

    private var aiHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("先看证据，再做决定")
                .font(.title2.weight(.bold))
                .foregroundStyle(HuJuTheme.ink)
            Text("把预算、通勤和现场记录放在一起，找出冲突与下一步。")
                .font(.subheadline)
                .foregroundStyle(HuJuTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(width: 32)
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
    }

    private func recommendationRow(index: Int, item: AIRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: "%02d", index + 1))
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(HuJuTheme.green)
                Text(item.property.name)
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                Spacer()
                Text("\(item.fitScore)")
                    .font(.title2.monospacedDigit().weight(.bold))
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
        .hujuCard()
    }
}

private struct BlindComparisonView: View {
    private enum Choice: Equatable {
        case first
        case second
    }

    @EnvironmentObject private var store: PropertyStore
    @State private var firstID: UUID?
    @State private var secondID: UUID?
    @State private var hasStarted = false
    @State private var choice: Choice?

    private var listings: [PropertyListing] {
        store.listings.filter { $0.status != .archived }
    }

    private var first: PropertyListing? {
        listings.first { $0.id == firstID }
    }

    private var second: PropertyListing? {
        listings.first { $0.id == secondID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if listings.count < 2 {
                    ContentUnavailableView(
                        "至少需要两套候选",
                        systemImage: "rectangle.on.rectangle.slash",
                        description: Text("先在看房日志中记录两套未排除的房源。")
                    )
                } else if !hasStarted {
                    selectionPanel
                } else if let first, let second {
                    comparisonPanel(first: first, second: second)
                }
            }
            .padding(16)
        }
        .background(HuJuTheme.paper)
        .navigationTitle("盲选对比")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard firstID == nil, secondID == nil else { return }
            firstID = listings.first?.id
            secondID = listings.dropFirst().first?.id
        }
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(eyebrow: "盲选对比", title: "选择两套候选")
            Picker("方案甲", selection: $firstID) {
                ForEach(listings) { listing in
                    Text(listing.name).tag(Optional(listing.id))
                }
            }
            Picker("方案乙", selection: $secondID) {
                ForEach(listings) { listing in
                    Text(listing.name).tag(Optional(listing.id))
                }
            }
            Button {
                choice = nil
                hasStarted = true
            } label: {
                Label("开始盲选", systemImage: "eye.slash.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(HuJuTheme.deepGreen)
            .disabled(firstID == nil || secondID == nil || firstID == secondID)
        }
        .padding(16)
        .hujuCard()
    }

    private func comparisonPanel(first: PropertyListing, second: PropertyListing) -> some View {
        VStack(spacing: 16) {
            HStack {
                blindHeader("甲", color: HuJuTheme.green)
                blindHeader("乙", color: HuJuTheme.blue)
            }

            comparisonRow("总价", "\(Int(first.totalPrice)) 万", "\(Int(second.totalPrice)) 万")
            comparisonRow("面积", "\(Int(first.size)) 平方米", "\(Int(second.size)) 平方米")
            comparisonRow("户型", first.rooms, second.rooms)
            comparisonRow("通勤", "\(first.commuteMinutes) 分钟", "\(second.commuteMinutes) 分钟")
            comparisonRow(
                "证据",
                evidenceText(first),
                evidenceText(second)
            )
            comparisonRow("已知风险", "\(first.concerns.count) 项", "\(second.concerns.count) 项")

            if let choice {
                let selected = choice == .first ? first : second
                VStack(alignment: .leading, spacing: 6) {
                    Text("你的直觉选择")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HuJuTheme.muted)
                    Text(selected.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text("\(selected.district) · \(selected.area)")
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(HuJuTheme.yellow.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("重新盲选") {
                    hasStarted = false
                    self.choice = nil
                }
                .buttonStyle(.bordered)
            } else {
                HStack(spacing: 12) {
                    choiceButton("选择甲", choice: .first, color: HuJuTheme.green)
                    choiceButton("选择乙", choice: .second, color: HuJuTheme.blue)
                }
            }
        }
    }

    private func blindHeader(_ title: String, color: Color) -> some View {
        Text("方案 \(title)")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func comparisonRow(_ title: String, _ firstValue: String, _ secondValue: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(HuJuTheme.muted)
            HStack {
                Text(firstValue)
                    .frame(maxWidth: .infinity)
                Divider()
                Text(secondValue)
                    .frame(maxWidth: .infinity)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(HuJuTheme.ink)
        }
        .padding(12)
        .hujuCard()
    }

    private func evidenceText(_ listing: PropertyListing) -> String {
        let report = EvidenceEngine.report(for: listing)
        return "\(report.completedCount)/\(report.totalCount)"
    }

    private func choiceButton(_ title: String, choice: Choice, color: Color) -> some View {
        Button(title) {
            self.choice = choice
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CoupleReviewView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var selectedID: UUID?
    @State private var partnerScore = 7
    @State private var revealed = false

    private var listings: [PropertyListing] {
        store.listings.filter { $0.status != .archived }
    }

    private var selected: PropertyListing? {
        listings.first { $0.id == selectedID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if listings.isEmpty {
                    ContentUnavailableView("暂无候选", systemImage: "person.2.slash")
                } else {
                    Picker("共同评估", selection: $selectedID) {
                        ForEach(listings) { listing in
                            Text(listing.name).tag(Optional(listing.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let selected {
                        partnerInput(for: selected)
                    }
                }
            }
            .padding(16)
        }
        .background(HuJuTheme.paper)
        .navigationTitle("双人模式")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedID == nil {
                selectedID = listings.first?.id
                loadSavedScore()
            }
        }
        .onChange(of: selectedID) {
            revealed = false
            loadSavedScore()
        }
    }

    private func partnerInput(for listing: PropertyListing) -> some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(revealed ? listing.name : "请另一位购房者独立评分")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HuJuTheme.ink)
                Stepper("我的评分 \(partnerScore)/10", value: $partnerScore, in: 1...10)
                    .font(.headline)
            }
            .padding(16)
            .hujuCard()

            if revealed {
                let consensus = CoupleDecisionEngine.evaluate(
                    userScore: listing.score,
                    partnerScore: partnerScore
                )
                HStack(spacing: 12) {
                    scoreColumn("看房记录", score: listing.score, color: HuJuTheme.green)
                    scoreColumn("共同购房者", score: partnerScore, color: HuJuTheme.blue)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(consensus.title)
                        .font(.headline)
                        .foregroundStyle(consensus.needsDiscussion ? HuJuTheme.coral : HuJuTheme.green)
                    Text(consensus.detail)
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .hujuCard()
            } else {
                Button {
                    store.setPartnerScore(partnerScore, for: listing.id)
                    revealed = true
                } label: {
                    Label("提交并揭晓", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(HuJuTheme.deepGreen)
            }
        }
    }

    private func scoreColumn(_ title: String, score: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(HuJuTheme.muted)
            Text("\(score)")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .hujuCard()
    }

    private func loadSavedScore() {
        guard let selectedID else { return }
        partnerScore = store.partnerScores[selectedID] ?? 7
    }
}

private struct BuyingPlanView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var showBudgetEditor = false
    @State private var selectedMarket = HousingMarketKind.newHome
    @State private var selectedMetric = MarketMetric.monthOverMonth
    @State private var selectedRange = MarketTimeRange.sixMonths
    @State private var selectedYear = 2026

    private let marketData = MarketDataLoader.load()

    private var buyingProgress: BuyingPlanProgress {
        BuyingPlanEngine.progress(
            listings: store.listings,
            profile: store.budget,
            completedManualTaskIDs: store.completedBuyingPlanTaskIDs
        )
    }

    private var snapshot: BudgetSnapshot {
        BudgetEngine.snapshot(for: store.budget)
    }

    private var commuteTarget: Binding<Int> {
        Binding(
            get: { store.budget.maxCommuteMinutes ?? 45 },
            set: { store.budget.maxCommuteMinutes = $0 }
        )
    }

    private var marketSeries: [MarketIndexPoint] {
        market.series(for: selectedMarket, range: selectedRange)
    }

    private var market: MarketRadarSnapshot {
        marketData.snapshot(city: "上海", year: selectedYear)
            ?? MarketRadarSnapshot.shanghai
    }

    private var latestMarketPoint: MarketIndexPoint? {
        marketSeries.last
    }

    private var marketColor: Color {
        selectedMarket == .newHome ? HuJuTheme.green : HuJuTheme.blue
    }

    private var chartDomain: ClosedRange<Double> {
        let values = marketSeries.map { $0.change(for: selectedMetric) }
        let lower = min(values.min() ?? 0, 0)
        let upper = max(values.max() ?? 0, 0)
        let padding = max(0.2, (upper - lower) * 0.15)
        return (lower - padding)...(upper + padding)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        marketPanel
                        budgetPanel
                        buyingPlanSummary
                            .id("buying-plan")
                        policyNotice
                    }
                    .padding(16)
                }
                .background(HuJuTheme.paper)
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("-showPlan") {
                        DispatchQueue.main.async {
                            proxy.scrollTo("buying-plan", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("市场")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showBudgetEditor) {
            BudgetEditorView(profile: store.budget) { updated in
                store.budget = updated
            }
        }
    }

    private var marketPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(
                eyebrow: "国家统计局官方指数",
                title: "上海房价指数",
                action: market.period
            )

            HStack(spacing: 10) {
                Label("上海", systemImage: "building.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HuJuTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)

                Menu {
                    Picker("年份", selection: $selectedYear) {
                        ForEach(marketData.availableYears, id: \.self) { year in
                            Text(verbatim: "\(year) 年").tag(year)
                        }
                    }
                } label: {
                    Label {
                        Text(verbatim: "\(selectedYear) 年")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HuJuTheme.blue)
                        .frame(minHeight: 44)
                }
            }

            Picker("住宅类型", selection: $selectedMarket) {
                ForEach(HousingMarketKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Picker("指标", selection: $selectedMetric) {
                    ForEach(MarketMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                Picker("时间范围", selection: $selectedRange) {
                    ForEach(MarketTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 88)
            }

            if let latest = latestMarketPoint {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    marketMetric(
                        title: "环比",
                        value: percent(latest.monthOverMonthChange),
                        change: latest.monthOverMonthChange
                    )
                    marketMetric(
                        title: "同比",
                        value: percent(latest.yearOverYearChange),
                        change: latest.yearOverYearChange
                    )
                    Spacer(minLength: 0)
                }
            }

            Chart {
                RuleMark(y: .value("持平", 0))
                    .foregroundStyle(HuJuTheme.line)

                ForEach(marketSeries) { point in
                    LineMark(
                        x: .value("月份", point.monthLabel),
                        y: .value(selectedMetric.rawValue, point.change(for: selectedMetric))
                    )
                    .foregroundStyle(marketColor)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("月份", point.monthLabel),
                        y: .value(selectedMetric.rawValue, point.change(for: selectedMetric))
                    )
                    .foregroundStyle(marketColor)
                }
            }
            .chartYScale(domain: chartDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(percent(number))
                        }
                    }
                }
            }
            .frame(height: 170)
            .accessibilityLabel(
                "\(selectedMarket.rawValue)\(selectedRange.rawValue)\(selectedMetric.rawValue)价格指数趋势"
            )

            let reading = market.reading(for: selectedMarket, metric: selectedMetric)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(marketColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reading.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text(reading.detail)
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .hujuCard()
    }

    private func marketMetric(title: String, value: String, change: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(HuJuTheme.muted)
            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(change >= 0 ? HuJuTheme.green : HuJuTheme.coral)
        }
    }

    private var budgetPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("个人规划")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HuJuTheme.muted)
                    Text("我的承受边界")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                }
                Spacer()
                Button {
                    showBudgetEditor = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .tint(HuJuTheme.green)
                .accessibilityLabel("编辑个人规划")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("目标总价")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(store.budget.totalBudget)) 万")
                        .font(.title3.monospacedDigit().weight(.bold))
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

            Stepper(
                "单程通勤上限 \(commuteTarget.wrappedValue) 分钟",
                value: commuteTarget,
                in: 15...120,
                step: 5
            )
            .font(.subheadline.weight(.semibold))

            HStack(spacing: 0) {
                budgetMetric("首付估算", value: "\(Int(snapshot.downPayment)) 万")
                Divider().frame(height: 44)
                budgetMetric("税费预留", value: "\(Int(snapshot.estimatedTaxesAndFees)) 万")
                Divider().frame(height: 44)
                budgetMetric("月供估算", value: String(format: "%.1f 万", snapshot.monthlyPayment))
            }
        }
        .padding(16)
        .hujuCard()
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

    private var buyingPlanSummary: some View {
        VStack(spacing: 12) {
            SectionHeading(
                eyebrow: "购房流程",
                title: "当前购房进度",
                action: "\(buyingProgress.completedCount)/\(buyingProgress.tasks.count)"
            )

            NavigationLink {
                BuyingJourneyView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: buyingProgress.currentStage.symbol)
                        .font(.title3)
                        .foregroundStyle(HuJuTheme.blue)
                        .frame(width: 42, height: 42)
                        .background(HuJuTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("当前处于\(buyingProgress.currentStage.title)阶段")
                            .font(.headline)
                            .foregroundStyle(HuJuTheme.ink)
                        Text(buyingProgress.currentStage.guidance)
                            .font(.caption)
                            .foregroundStyle(HuJuTheme.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(HuJuTheme.muted)
                }
                .padding(13)
                .hujuCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var policyNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(HuJuTheme.blue)
                Text("国家统计局数据是上海城市级价格指数，不代表具体板块均价或未来涨跌。政策、贷款、税费和学区信息请在交易前复核。")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
            }

            if let url = URL(string: market.sourceURL) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "building.columns.fill")
                        Text(market.sourceName)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HuJuTheme.blue)
                    .frame(minHeight: 44)
                }
            }

            Text("发布于 \(market.publishedAt) · 上海历史数据")
                .font(.caption2)
                .foregroundStyle(HuJuTheme.muted)
        }
        .padding(.bottom, 10)
    }

    private func percent(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }
}

private struct BuyingPlanTaskRow: View {
    let task: BuyingPlanTask
    var showsStage = false
    let onToggle: () -> Void

    var body: some View {
        Group {
            if task.kind == .manual {
                Button(action: onToggle) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .padding(13)
        .hujuCard()
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HuJuTheme.ink)
                    if showsStage {
                        Text(task.stage.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HuJuTheme.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(HuJuTheme.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(task.detail)
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(task.isComplete ? HuJuTheme.green : HuJuTheme.blue)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var symbol: String {
        if task.isComplete { return "checkmark.circle.fill" }
        return task.kind == .automatic ? "bolt.circle.fill" : "circle"
    }

    private var iconColor: Color {
        if task.isComplete { return HuJuTheme.green }
        return task.kind == .automatic ? HuJuTheme.blue : HuJuTheme.muted
    }

    private var statusText: String {
        if task.isComplete { return "已完成" }
        return task.kind == .automatic ? "根据当前数据自动判断" : "点击确认完成"
    }
}

private struct BuyingJourneyView: View {
    @EnvironmentObject private var store: PropertyStore

    private var progress: BuyingPlanProgress {
        BuyingPlanEngine.progress(
            listings: store.listings,
            profile: store.budget,
            completedManualTaskIDs: store.completedBuyingPlanTaskIDs
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("当前处于\(progress.currentStage.title)阶段")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(HuJuTheme.ink)
                            Text(progress.currentStage.guidance)
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                        }
                        Spacer()
                        Text("\(progress.completedCount)/\(progress.tasks.count)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(HuJuTheme.green)
                    }
                    ProgressView(value: progress.completionRatio)
                        .tint(HuJuTheme.green)
                }
                .padding(16)
                .hujuCard()

                ForEach(BuyingJourneyStage.allCases) { stage in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: progress.isComplete(stage) ? "checkmark.circle.fill" : stage.symbol)
                                .foregroundStyle(progress.isComplete(stage) ? HuJuTheme.green : HuJuTheme.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stage.title)
                                    .font(.headline)
                                    .foregroundStyle(HuJuTheme.ink)
                                Text(stage.guidance)
                                    .font(.caption2)
                                    .foregroundStyle(HuJuTheme.muted)
                            }
                        }

                        ForEach(progress.tasks(for: stage)) { task in
                            BuyingPlanTaskRow(task: task) {
                                store.toggleBuyingPlanTask(task.id)
                            }
                        }
                    }
                    .padding(14)
                }
            }
            .padding(16)
        }
        .background(HuJuTheme.paper)
        .navigationTitle("购房计划")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FieldVisitView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PropertyStore
    @State private var selectedID: UUID?

    private var listings: [PropertyListing] {
        store.listings.filter { $0.status != .archived }
    }

    private var selected: PropertyListing? {
        listings.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if listings.isEmpty {
                        ContentUnavailableView("暂无可核验房源", systemImage: "location.slash")
                    } else {
                        Picker("正在看", selection: $selectedID) {
                            ForEach(listings) { listing in
                                Text(listing.name).tag(Optional(listing.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let selected {
                            fieldHeader(for: selected)
                            PropertyMediaCaptureControls(
                                attachments: selected.mediaAttachments ?? []
                            ) { attachment in
                                store.addMediaAttachment(attachment, for: selected.id)
                            }
                            .padding(14)
                            .hujuCard()
                            evidenceChecklist(for: selected)
                        }
                    }
                }
                .padding(16)
            }
            .background(HuJuTheme.paper)
            .navigationTitle("现场模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                if selectedID == nil {
                    selectedID = listings.first?.id
                }
            }
        }
    }

    private func fieldHeader(for listing: PropertyListing) -> some View {
        let report = EvidenceEngine.report(for: listing)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(listing.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text("\(listing.district) · \(listing.area)")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                }
                Spacer()
                Text("\(report.completedCount)/\(report.totalCount)")
                    .font(.title2.monospacedDigit().weight(.black))
                    .foregroundStyle(HuJuTheme.green)
            }
            ProgressView(value: report.completionRatio)
                .tint(HuJuTheme.green)
        }
        .padding(16)
        .hujuCard()
    }

    private func evidenceChecklist(for listing: PropertyListing) -> some View {
        let report = EvidenceEngine.report(for: listing)

        return VStack(spacing: 10) {
            ForEach(report.items) { item in
                let manuallyVerified = listing.verifiedEvidence?.contains(item.kind) == true
                Button {
                    store.setEvidence(item.kind, completed: !manuallyVerified, for: listing.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isComplete ? HuJuTheme.green : HuJuTheme.muted)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.kind.title)
                                .font(.headline)
                                .foregroundStyle(HuJuTheme.ink)
                            Text(item.kind.action)
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(13)
                    .frame(minHeight: 58)
                    .hujuCard()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AddPropertyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var district = "浦东新区"
    @State private var area = ""
    @State private var unitLabel = ""
    @State private var building = ""
    @State private var floorDescription = ""
    @State private var sourceURL = ""
    @State private var totalPrice = 600.0
    @State private var size = 80.0
    @State private var rooms = "2室2厅"
    @State private var orientation = "待确认"
    @State private var buildYear = ""
    @State private var metroDistance = ""
    @State private var commuteMinutes = 45
    @State private var score = 8.0
    @State private var note = ""
    @State private var mediaAttachments: [PropertyMediaAttachment] = []
    @State private var savedListing: PropertyListing?

    let profile: BudgetProfile
    let onSave: (PropertyListing) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let savedListing {
                    analysisResult(for: savedListing)
                } else {
                    propertyForm
                }
            }
            .navigationTitle(savedListing == nil ? "记录一次看房" : "分析完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if savedListing == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            LocalPropertyMediaStore.remove(mediaAttachments)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存并分析") { save() }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
    }

    private var propertyForm: some View {
        Form {
            Section("楼盘位置") {
                TextField("楼盘或小区名", text: $name)
                Picker("行政区", selection: $district) {
                    ForEach(["浦东新区", "闵行区", "徐汇区", "杨浦区", "宝山区", "嘉定区", "松江区"], id: \.self) {
                        Text($0)
                    }
                }
                TextField("板块", text: $area)
                TextField("房源标签（例如 80 平南向两房）", text: $unitLabel)
                TextField("房源原始链接（选填）", text: $sourceURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            Section("房源事实") {
                LabeledContent("总价", value: "\(Int(totalPrice)) 万")
                Slider(value: $totalPrice, in: 200...1_500, step: 10)
                LabeledContent("面积", value: "\(Int(size)) 平方米")
                Slider(value: $size, in: 30...200, step: 1)
                Picker("户型", selection: $rooms) {
                    ForEach(["1室1厅", "2室1厅", "2室2厅", "3室1厅", "3室2厅", "4室及以上", "待补充"], id: \.self) {
                        Text($0)
                    }
                }
                Picker("主要朝向", selection: $orientation) {
                    ForEach(["待确认", "南", "南北", "东", "西", "北"], id: \.self) {
                        Text($0)
                    }
                }
                TextField("楼栋（选填）", text: $building)
                TextField("楼层（选填）", text: $floorDescription)
                TextField("建成年份（选填）", text: $buildYear)
                    .keyboardType(.numberPad)
                TextField("距地铁约多少米（选填）", text: $metroDistance)
                    .keyboardType(.numberPad)
            }

            Section("现场判断") {
                Stepper("通勤约 \(commuteMinutes) 分钟", value: $commuteMinutes, in: 5...180, step: 5)
                LabeledContent("现场评分", value: "\(Int(score))/10")
                Slider(value: $score, in: 1...10, step: 1)
                TextField("把最真实的感受留下来", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("现场影像") {
                PropertyMediaCaptureControls(
                    attachments: mediaAttachments
                ) { attachment in
                    mediaAttachments.append(attachment)
                }
            }
        }
    }

    private func analysisResult(for listing: PropertyListing) -> some View {
        let analysis = PropertyAnalyzer.analyze(listing, profile: profile)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(listing.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(HuJuTheme.ink)
                    Text("\(listing.district) · \(listing.area)")
                        .font(.subheadline)
                        .foregroundStyle(HuJuTheme.muted)
                    HStack {
                        MetricPill(
                            symbol: "banknote.fill",
                            text: "\(Int(listing.totalPrice)) 万",
                            tint: HuJuTheme.coral
                        )
                        MetricPill(
                            symbol: "square.split.2x2.fill",
                            text: listing.rooms,
                            tint: HuJuTheme.blue
                        )
                        MetricPill(
                            symbol: "tram.fill",
                            text: "\(listing.commuteMinutes) 分钟",
                            tint: HuJuTheme.green
                        )
                    }
                }

                PropertyAnalysisSections(analysis: analysis)

                Text("分析仅基于已录入事实和当前预算，不构成估价、贷款、税务、产权或学区意见。")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
            }
            .padding(18)
        }
        .background(HuJuTheme.paper)
    }

    private func save() {
        let listing = PropertyListing(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            district: district,
            area: area.isEmpty ? "待补充" : area,
            latitude: 31.2304,
            longitude: 121.4737,
            totalPrice: totalPrice,
            unitPrice: Int(totalPrice * 10_000 / size),
            size: size,
            rooms: rooms,
            visitDate: .now,
            status: .visited,
            score: Int(score),
            commuteMinutes: commuteMinutes,
            tags: [],
            highlights: [],
            concerns: [],
            note: note.isEmpty ? "刚刚完成现场看房，待补充证据。" : note,
            buildYear: Int(buildYear),
            orientation: orientation == "待确认" ? nil : orientation,
            metroDistanceMeters: Int(metroDistance),
            sourceURL: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
            mediaAttachments: mediaAttachments,
            unitLabel: unitLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : unitLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            building: building.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : building.trimmingCharacters(in: .whitespacesAndNewlines),
            floorDescription: floorDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : floorDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(listing)
        savedListing = listing
    }
}

private enum CameraCaptureMode: String, Identifiable {
    case photo
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: "拍照"
        case .video: "录像"
        }
    }

    var symbol: String {
        switch self {
        case .photo: "camera.fill"
        case .video: "video.fill"
        }
    }
}

private enum MediaCaptureError: LocalizedError {
    case unavailable
    case invalidResult
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "当前设备没有可用摄像头，请在真机上拍摄。"
        case .invalidResult:
            "没有获取到有效的照片或视频。"
        case .saveFailed:
            "影像保存失败，请检查设备存储空间。"
        }
    }
}

enum LocalPropertyMediaStore {
    static func savePhoto(_ image: UIImage) throws -> PropertyMediaAttachment {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw MediaCaptureError.saveFailed
        }
        let fileName = "\(UUID().uuidString).jpg"
        try data.write(to: try mediaDirectory().appendingPathComponent(fileName), options: .atomic)
        return PropertyMediaAttachment(
            id: UUID(),
            kind: .photo,
            fileName: fileName,
            createdAt: .now
        )
    }

    static func saveVideo(from sourceURL: URL) throws -> PropertyMediaAttachment {
        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)"
        let destination = try mediaDirectory().appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw MediaCaptureError.saveFailed
        }
        return PropertyMediaAttachment(
            id: UUID(),
            kind: .video,
            fileName: fileName,
            createdAt: .now
        )
    }

    static func remove(_ attachments: [PropertyMediaAttachment]) {
        guard let directory = try? mediaDirectory() else { return }
        for attachment in attachments {
            try? FileManager.default.removeItem(
                at: directory.appendingPathComponent(attachment.fileName)
            )
        }
    }

    private static func mediaDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("PropertyMedia", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

private struct PropertyMediaCaptureControls: View {
    let attachments: [PropertyMediaAttachment]
    let onCaptured: (PropertyMediaAttachment) -> Void

    @State private var captureMode: CameraCaptureMode?
    @State private var alertMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                captureButton(.photo)
                captureButton(.video)
            }

            if attachments.isEmpty {
                Text("尚未记录照片或视频")
                    .font(.caption)
                    .foregroundStyle(HuJuTheme.muted)
            } else {
                ForEach(attachments) { attachment in
                    Label(
                        "\(attachment.kind.title) · \(attachment.createdAt.formatted(date: .omitted, time: .shortened))",
                        systemImage: attachment.kind.symbol
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HuJuTheme.ink)
                }
            }
        }
        .sheet(item: $captureMode) { mode in
            CameraCaptureView(mode: mode) { result in
                switch result {
                case let .success(attachment):
                    onCaptured(attachment)
                case let .failure(error):
                    alertMessage = error.localizedDescription
                }
            }
            .ignoresSafeArea()
        }
        .alert(
            "无法拍摄",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func captureButton(_ mode: CameraCaptureMode) -> some View {
        Button {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                alertMessage = MediaCaptureError.unavailable.localizedDescription
                return
            }
            captureMode = mode
        } label: {
            Label(mode.title, systemImage: mode.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HuJuTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(HuJuTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let mode: CameraCaptureMode
    let onResult: (Result<PropertyMediaAttachment, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        controller.mediaTypes = [
            mode == .photo ? UTType.image.identifier : UTType.movie.identifier
        ]
        if mode == .video {
            controller.cameraCaptureMode = .video
            controller.videoQuality = .typeHigh
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onResult: (Result<PropertyMediaAttachment, Error>) -> Void

        init(onResult: @escaping (Result<PropertyMediaAttachment, Error>) -> Void) {
            self.onResult = onResult
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            do {
                let attachment: PropertyMediaAttachment
                if let image = info[.originalImage] as? UIImage {
                    attachment = try LocalPropertyMediaStore.savePhoto(image)
                } else if let videoURL = info[.mediaURL] as? URL {
                    attachment = try LocalPropertyMediaStore.saveVideo(from: videoURL)
                } else {
                    throw MediaCaptureError.invalidResult
                }
                onResult(.success(attachment))
            } catch {
                onResult(.failure(error))
            }
            picker.dismiss(animated: true)
        }
    }
}
