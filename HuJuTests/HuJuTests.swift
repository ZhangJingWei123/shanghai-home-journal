import AuthenticationServices
import Security
import XCTest

@testable import HuJu

private struct SuccessfulWeChatAuthenticator: WeChatAuthenticating {
    let user: AuthenticatedUser

    @MainActor
    func authenticate() async throws -> AuthenticatedUser {
        user
    }
}

private struct FailingWeChatAuthenticator: WeChatAuthenticating {
    let error: AuthenticationError

    @MainActor
    func authenticate() async throws -> AuthenticatedUser {
        throw error
    }
}

private struct StubAppleCredentialStateChecker: AppleCredentialStateChecking {
    let state: ASAuthorizationAppleIDProvider.CredentialState

    @MainActor
    func credentialState(
        for userID: String
    ) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        state
    }
}

private final class NonPersistingAuthSessionStore: AuthSessionPersisting {
    func load() -> AuthenticatedUser? {
        nil
    }

    func save(_ user: AuthenticatedUser) throws {
        throw AuthSessionPersistenceError.keychain(errSecNotAvailable)
    }

    func remove() throws {}
}

private final class NonRemovingAuthSessionStore: AuthSessionPersisting {
    private let storedUser: AuthenticatedUser

    init(storedUser: AuthenticatedUser) {
        self.storedUser = storedUser
    }

    func load() -> AuthenticatedUser? {
        storedUser
    }

    func save(_ user: AuthenticatedUser) throws {}

    func remove() throws {
        throw AuthSessionPersistenceError.keychain(errSecNotAvailable)
    }
}

final class HuJuTests: XCTestCase {
    @MainActor
    func testAuthenticationStore_emptyStorageStartsSignedOut_BitsUT() {
        let suiteName = "HuJuEmptyAuthenticationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AuthenticationStore(
            storage: UserDefaultsAuthSessionStore(defaults: defaults),
            allowsSimulatorLogin: false
        )

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(store.currentUser)
    }

    @MainActor
    func testPropertyStore_freshInstallStartsWithEmptyWorkspace_BitsUT() {
        let suiteName = "HuJuFreshInstallTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PropertyStore(defaults: defaults)

        XCTAssertTrue(store.listings.isEmpty)
        XCTAssertTrue(store.partnerScores.isEmpty)
    }

    @MainActor
    func testAuthenticationStore_loginPresentationCanBeDismissedWithoutAccount_BitsUT() {
        let suiteName = "HuJuLoginPresentationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AuthenticationStore(
            storage: UserDefaultsAuthSessionStore(defaults: defaults),
            allowsSimulatorLogin: false
        )

        store.presentLogin()
        XCTAssertTrue(store.isLoginPresented)

        store.continueWithoutAccount()
        XCTAssertFalse(store.isLoginPresented)
        XCTAssertFalse(store.isAuthenticated)
    }

    @MainActor
    func testPrepareAppleAuthorizationRequestsRequiredScopes_BitsUT() {
        let suiteName = "HuJuAppleAuthorizationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AuthenticationStore(
            storage: UserDefaultsAuthSessionStore(defaults: defaults),
            allowsSimulatorLogin: false
        )
        let request = ASAuthorizationAppleIDProvider().createRequest()

        store.prepareAppleAuthorization(request)

        XCTAssertTrue(store.isWorking)
        XCTAssertEqual(
            Set(request.requestedScopes ?? []),
            Set([ASAuthorization.Scope.fullName, .email])
        )
    }

    @MainActor
    func testPropertyStore_sampleDataRequiresExplicitAction_BitsUT() {
        let suiteName = "HuJuSampleDataTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PropertyStore(defaults: defaults)
        XCTAssertTrue(store.listings.isEmpty)

        store.loadSampleData()

        XCTAssertEqual(store.listings.count, PropertyStore.samples.count)
        XCTAssertTrue(store.isUsingSampleData)

        let restored = PropertyStore(defaults: defaults)
        XCTAssertEqual(restored.listings.count, PropertyStore.samples.count)
        XCTAssertTrue(restored.isUsingSampleData)
    }

    @MainActor
    func testPropertyStore_legacySampleRecordsAreMarkedAsSampleData_BitsUT() throws {
        let suiteName = "HuJuLegacySampleDataTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(
            try JSONEncoder().encode(PropertyStore.samples),
            forKey: "huju.listings.v1"
        )

        let store = PropertyStore(defaults: defaults)

        XCTAssertTrue(store.isUsingSampleData)
        XCTAssertEqual(store.listings.count, PropertyStore.samples.count)
    }

    @MainActor
    func testPropertyStore_deleteAllUserDataClearsPersistedState_BitsUT() {
        let suiteName = "HuJuDataDeletionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PropertyStore(defaults: defaults, loadsSampleData: true)
        let listingID = store.listings[0].id
        store.setPartnerScore(9, for: listingID)
        store.selectCity("北京市")
        store.budget.totalBudget = 900

        store.deleteAllUserData()

        XCTAssertTrue(store.listings.isEmpty)
        XCTAssertTrue(store.partnerScores.isEmpty)
        XCTAssertFalse(store.isUsingSampleData)
        XCTAssertNil(store.selectedCity)
        XCTAssertEqual(store.budget, BudgetProfile())

        let restored = PropertyStore(defaults: defaults)
        XCTAssertTrue(restored.listings.isEmpty)
        XCTAssertNil(restored.selectedCity)
        XCTAssertEqual(restored.budget, BudgetProfile())
    }

    @MainActor
    func testLegacyListingWithoutCityDecodesAsShanghai() throws {
        var legacyListing = PropertyStore.samples[0]
        legacyListing.city = nil

        let data = try JSONEncoder().encode(legacyListing)
        let decoded = try JSONDecoder().decode(PropertyListing.self, from: data)

        XCTAssertNil(decoded.city)
        XCTAssertEqual(decoded.resolvedCity, "上海")
        XCTAssertTrue(decoded.locationSummary.hasPrefix("上海"))
    }

    @MainActor
    func testPropertyStoreFiltersListingsByCityAndRestoresNationalScope() {
        let store = PropertyStore(defaults: nil, loadsSampleData: true)

        XCTAssertEqual(store.visibleListings.count, PropertyStore.samples.count)

        store.selectCity("北京市")
        XCTAssertEqual(store.selectedCity, "北京")
        XCTAssertEqual(store.visibleListings.map(\.resolvedCity), ["北京"])

        store.selectCity("上海")
        XCTAssertEqual(store.visibleListings.count, 4)
        XCTAssertTrue(store.visibleListings.allSatisfy { $0.resolvedCity == "上海" })

        store.selectCity(nil)
        XCTAssertEqual(store.visibleListings.count, PropertyStore.samples.count)
    }

    @MainActor
    func testPropertyStorePersistsSelectedCityAndAppliesItToNewListing() {
        let suiteName = "HuJuCitySelectionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PropertyStore(defaults: defaults)
        store.selectCity("广州市")
        var listing = PropertyStore.samples[0]
        listing.city = nil
        store.add(listing)

        XCTAssertEqual(store.listings.first?.resolvedCity, "广州")

        let restored = PropertyStore(defaults: defaults)
        XCTAssertEqual(restored.selectedCity, "广州")
        XCTAssertEqual(restored.visibleListings.count, 1)
        XCTAssertEqual(restored.visibleListings.first?.resolvedCity, "广州")
    }

    @MainActor
    func testSignInWithWeChat_persistenceFailureDoesNotAuthenticate_BitsUT() async {
        let user = AuthenticatedUser(
            id: "wechat-user-persistence-failure",
            displayName: "Test User",
            provider: .weChat
        )
        let store = AuthenticationStore(
            storage: NonPersistingAuthSessionStore(),
            weChatAuthenticator: SuccessfulWeChatAuthenticator(user: user),
            allowsSimulatorLogin: false
        )

        await store.signInWithWeChat()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNotNil(store.errorMessage)
    }

    @MainActor
    func testSignOut_persistenceRemovalFailureKeepsSessionVisible_BitsUT() {
        let user = AuthenticatedUser(
            id: "apple-user-removal-failure",
            displayName: "Test User",
            provider: .apple
        )
        let store = AuthenticationStore(
            storage: NonRemovingAuthSessionStore(storedUser: user),
            allowsSimulatorLogin: false
        )

        store.signOut()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertNotNil(store.errorMessage)
    }

    @MainActor
    func testSignInWithWeChat_authenticatorFailureShowsError_BitsUT() async {
        let store = AuthenticationStore(
            storage: NonPersistingAuthSessionStore(),
            weChatAuthenticator: FailingWeChatAuthenticator(error: .serverRejected),
            allowsSimulatorLogin: false
        )

        await store.signInWithWeChat()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertEqual(
            store.errorMessage,
            AuthenticationError.serverRejected.localizedDescription
        )
        XCTAssertFalse(store.isWorking)
    }

    @MainActor
    func testSignInWithWeChat_cancelledDoesNotShowError_BitsUT() async {
        let store = AuthenticationStore(
            storage: NonPersistingAuthSessionStore(),
            weChatAuthenticator: FailingWeChatAuthenticator(error: .cancelled),
            allowsSimulatorLogin: false
        )

        await store.signInWithWeChat()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isWorking)
    }

    @MainActor
    func testValidateStoredSession_transferredCredentialSignsOut_BitsUT() async {
        let suiteName = "HuJuTransferredCredentialTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storage = UserDefaultsAuthSessionStore(defaults: defaults)
        let user = AuthenticatedUser(
            id: "apple-user-transferred",
            displayName: "Test User",
            provider: .apple
        )
        try? storage.save(user)
        let store = AuthenticationStore(
            storage: storage,
            appleCredentialStateChecker: StubAppleCredentialStateChecker(state: .transferred),
            allowsSimulatorLogin: false
        )

        await store.validateStoredSession()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(storage.load())
    }

    @MainActor
    func testWeChatLoginPersistsMinimalSessionAndCanSignOut() async {
        let suiteName = "HuJuAuthenticationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let expected = AuthenticatedUser(
            id: "wechat-user-1",
            displayName: "看房人",
            provider: .weChat
        )
        let storage = UserDefaultsAuthSessionStore(defaults: defaults)
        let store = AuthenticationStore(
            storage: storage,
            weChatAuthenticator: SuccessfulWeChatAuthenticator(user: expected),
            allowsSimulatorLogin: false
        )

        await store.signInWithWeChat()

        XCTAssertEqual(store.currentUser, expected)
        XCTAssertEqual(storage.load(), expected)

        store.signOut()

        XCTAssertNil(store.currentUser)
        XCTAssertNil(storage.load())
    }

    @MainActor
    func testSimulatorLoginEntersWorkspaceWithoutExternalCredentials() async {
        let suiteName = "HuJuSimulatorLoginTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AuthenticationStore(
            storage: UserDefaultsAuthSessionStore(defaults: defaults),
            allowsSimulatorLogin: true
        )

        await store.signInWithWeChat()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.currentUser?.displayName, "看房体验账号")
        XCTAssertEqual(store.currentUser?.provider, .weChat)

        store.signOut()
        store.signInWithApple()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.currentUser?.provider, .apple)
    }

    func testAuthenticationErrorMessagesRemainChineseAndActionable() {
        XCTAssertEqual(
            AuthenticationError.weChatNotConfigured.localizedDescription,
            "微信登录尚未配置开放平台与服务端地址。"
        )
        XCTAssertEqual(
            AuthenticationError.invalidCallback.localizedDescription,
            "登录回调校验失败，请重新发起登录。"
        )
    }

    func testBudgetSnapshotUsesFirstHomeDownPaymentAndAmortizedLoan() {
        let profile = BudgetProfile(
            totalBudget: 600,
            availableCash: 180,
            monthlyIncome: 6,
            loanYears: 30,
            annualRate: 3,
            isFirstHome: true
        )

        let result = BudgetEngine.snapshot(for: profile)

        XCTAssertEqual(result.downPayment, 90, accuracy: 0.001)
        XCTAssertEqual(result.estimatedTaxesAndFees, 15, accuracy: 0.001)
        XCTAssertEqual(result.reserve, 24, accuracy: 0.001)
        XCTAssertGreaterThan(result.monthlyPayment, 2)
        XCTAssertLessThan(result.monthlyPayment, 2.3)
        XCTAssertLessThanOrEqual(result.cashGap, 0)
    }

    @MainActor
    func testAIAdvisorRanksAffordableShortCommutePropertyFirst() {
        var listings = PropertyStore.samples
        listings[0].totalPrice = 620
        listings[0].commuteMinutes = 30
        listings[0].score = 9
        listings[1].totalPrice = 900
        listings[1].commuteMinutes = 70
        listings[1].score = 6

        let result = LocalAIAdvisor().recommendations(
            listings: Array(listings.prefix(2)),
            profile: BudgetProfile(totalBudget: 650)
        )

        XCTAssertEqual(result.first?.property.id, listings[0].id)
        XCTAssertTrue(result.first?.reasons.contains("总价在当前预算内") == true)
        XCTAssertFalse(result.first?.missingChecks.isEmpty == true)
    }

    @MainActor
    func testArchivedPropertyIsNotRecommended() {
        guard let archived = PropertyStore.samples.first(where: { $0.status == .archived }) else {
            return XCTFail("Sample data must contain an archived property")
        }

        let result = LocalAIAdvisor().recommendations(
            listings: [archived],
            profile: BudgetProfile()
        )

        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testPropertyAnalyzerExplainsAdvantagesFromRecordedFacts() {
        var listing = PropertyStore.samples[0]
        listing.totalPrice = 620
        listing.commuteMinutes = 35
        listing.score = 9
        listing.orientation = "南北"
        listing.metroDistanceMeters = 650
        listing.buildYear = 2020
        listing.sourceURL = "https://example.com/listing/1"

        let result = PropertyAnalyzer.analyze(
            listing,
            profile: BudgetProfile(totalBudget: 650, maxCommuteMinutes: 45),
            currentYear: 2026
        )

        XCTAssertTrue(result.advantages.contains { $0.title == "总价在预算内" })
        XCTAssertTrue(result.advantages.contains { $0.title == "通勤符合预期" })
        XCTAssertTrue(result.advantages.contains { $0.title == "主要朝向较理想" })
        XCTAssertTrue(result.advantages.contains { $0.title == "地铁步行距离较近" })
        XCTAssertTrue(result.advantages.contains { $0.title == "房龄较新" })
        XCTAssertFalse(result.advantages.contains { $0.evidence.isEmpty })
    }

    @MainActor
    func testPropertyAnalyzerSeparatesDrawbacksAndMissingChecks() {
        var listing = PropertyStore.samples[0]
        listing.totalPrice = 720
        listing.commuteMinutes = 65
        listing.score = 4
        listing.rooms = "待补充"
        listing.orientation = "北"
        listing.metroDistanceMeters = 1_800
        listing.buildYear = 1995
        listing.sourceURL = nil
        listing.tags = []
        listing.concerns = []
        listing.note = "待复看"

        let result = PropertyAnalyzer.analyze(
            listing,
            profile: BudgetProfile(totalBudget: 650, maxCommuteMinutes: 45),
            currentYear: 2026
        )

        XCTAssertTrue(result.drawbacks.contains { $0.title == "总价超出预算" })
        XCTAssertTrue(result.drawbacks.contains { $0.title == "通勤超过预期" })
        XCTAssertTrue(result.drawbacks.contains { $0.title == "主要朝向受限" })
        XCTAssertTrue(result.drawbacks.contains { $0.title == "地铁步行距离较远" })
        XCTAssertTrue(result.drawbacks.contains { $0.title == "房龄偏长" })
        XCTAssertTrue(result.missingChecks.contains { $0.title == "保留房源来源" })
        XCTAssertTrue(result.missingChecks.contains { $0.title == "产权与抵押核验" })
        XCTAssertTrue(result.missingChecks.contains { $0.title == "分时段核验噪音" })
    }

    func testMarketRadarSnapshotHasChronologicalOfficialSeries() {
        let market = MarketRadarSnapshot.shanghai

        XCTAssertEqual(market.period, "2026 年 7 月")
        XCTAssertEqual(market.publishedAt, "2026-08-17")
        XCTAssertEqual(market.newHome.count, 12)
        XCTAssertEqual(market.resale.count, 12)
        XCTAssertEqual(market.newHome.first?.id, "2025-8")
        XCTAssertEqual(market.newHome.last?.id, "2026-7")
        XCTAssertEqual(market.newHome.last?.monthOverMonthChange ?? .nan, 0.2, accuracy: 0.001)
        XCTAssertEqual(market.newHome.last?.yearOverYearChange ?? .nan, 3.0, accuracy: 0.001)
        XCTAssertEqual(market.resale.last?.monthOverMonthChange ?? .nan, 0.3, accuracy: 0.001)
        XCTAssertEqual(market.resale.last?.yearOverYearChange ?? .nan, -2.0, accuracy: 0.001)
    }

    func testMarketRadarReadingKeepsMonthlyAndAnnualSignalsSeparate() {
        let market = MarketRadarSnapshot.shanghai
        let resaleReading = market.reading(for: .resale, metric: .yearOverYear)

        XCTAssertEqual(resaleReading.title, "同比仍低于上年同期")
        XCTAssertTrue(resaleReading.detail.contains("环比+0.3%"))
        XCTAssertEqual(market.series(for: .newHome, range: .threeMonths).map(\.month), [5, 6, 7])
        XCTAssertEqual(market.series(for: .resale, range: .sixMonths).count, 6)
        XCTAssertEqual(
            market.areaBands(for: .newHome).last?.yearOverYearChange ?? .nan,
            5.5,
            accuracy: 0.001
        )
    }

    func testBundledMarketDataSupportsSeventyCitiesAndHistoricalYears() {
        let dataset = MarketDataLoader.load()

        XCTAssertEqual(dataset.cities.count, 70)
        XCTAssertEqual(dataset.availableYears, [2026, 2025, 2024])
        XCTAssertTrue(dataset.cityNames.contains("上海"))
        XCTAssertTrue(dataset.cityNames.contains("北京"))
        XCTAssertTrue(dataset.cityNames.contains("成都"))

        let shanghai2024 = dataset.snapshot(city: "上海", year: 2024)
        XCTAssertEqual(shanghai2024?.newHome.count, 12)
        XCTAssertEqual(shanghai2024?.resale.count, 12)
        XCTAssertEqual(shanghai2024?.newHome.first?.monthOverMonthIndex ?? .nan, 100.4, accuracy: 0.001)
        let shanghai2026 = dataset.snapshot(city: "上海", year: 2026)
        XCTAssertEqual(shanghai2026?.newHome.count, 7)
        XCTAssertEqual(
            shanghai2026?.series(for: .resale, range: .threeMonths).map(\.month),
            [5, 6, 7]
        )

        let beijing2026 = dataset.snapshot(city: "北京", year: 2026)
        XCTAssertEqual(beijing2026?.newHome.count, 7)
        XCTAssertEqual(beijing2026?.resale.count, 7)
        XCTAssertEqual(beijing2026?.sourceName, "国家统计局 · 70 个大中城市住宅销售价格指数")
    }

    @MainActor
    func testEvidenceReportDrivesCompletenessAndReviewTasks() {
        var listing = PropertyStore.samples[0]
        listing.orientation = "南北"
        listing.metroDistanceMeters = 650
        listing.buildYear = 2020
        listing.verifiedEvidence = VisitEvidenceKind.allCases

        let report = EvidenceEngine.report(for: listing)

        XCTAssertEqual(report.completedCount, report.totalCount)
        XCTAssertEqual(report.completionRatio, 1, accuracy: 0.001)
        XCTAssertTrue(report.reviewTasks.isEmpty)
    }

    func testCoupleDecisionEngineFlagsLargeScoreDifference() {
        let result = CoupleDecisionEngine.evaluate(userScore: 9, partnerScore: 5)

        XCTAssertEqual(result.difference, 4)
        XCTAssertEqual(result.title, "核心判断不同")
        XCTAssertTrue(result.needsDiscussion)
    }

    @MainActor
    func testTenYearCostIncludesCashComponentsAndCommuteTime() {
        let listing = PropertyStore.samples[0]
        let result = TenYearCostEngine.snapshot(
            for: listing,
            profile: BudgetProfile(
                totalBudget: 650,
                availableCash: 230,
                monthlyIncome: 5.8,
                loanYears: 30,
                annualRate: 3.05,
                isFirstHome: true
            )
        )

        let componentTotal = result.downPayment
            + result.mortgagePayments
            + result.estimatedTaxesAndFees
            + result.estimatedRenovation
            + result.estimatedPropertyFees
        XCTAssertEqual(result.totalCashOutflow, componentTotal, accuracy: 0.001)
        XCTAssertEqual(result.commuteHours, Double(listing.commuteMinutes * 80), accuracy: 0.001)
    }

    @MainActor
    func testFieldEvidenceAndPartnerScorePersistLocally() {
        let suiteName = "HuJuTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let listingID = PropertyStore.samples[0].id

        let store = PropertyStore(defaults: defaults, loadsSampleData: true)
        store.setEvidence(.waterAndDamage, completed: true, for: listingID)
        store.setPartnerScore(9, for: listingID)

        let restored = PropertyStore(defaults: defaults)
        let listing = restored.listings.first { $0.id == listingID }
        XCTAssertTrue(listing?.verifiedEvidence?.contains(.waterAndDamage) == true)
        XCTAssertEqual(restored.partnerScores[listingID], 9)
    }

    @MainActor
    func testTimelineEngineSynthesizesDiscoveryForLegacyListing() {
        var listing = PropertyStore.samples[1]
        listing.timeline = nil

        let events = PropertyTimelineEngine.events(for: listing)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].id, listing.id)
        XCTAssertEqual(events[0].kind, .discovered)
        XCTAssertEqual(events[0].price ?? .nan, listing.totalPrice, accuracy: 0.001)
    }

    @MainActor
    func testTimelinePriceAndAvailabilityChangesPersist() {
        let suiteName = "HuJuTimelineTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PropertyStore(defaults: defaults, loadsSampleData: true)
        let listingID = store.listings[0].id
        let newPrice = store.listings[0].totalPrice - 12

        XCTAssertTrue(
            store.recordTimelineEvent(
                .priceChanged,
                for: listingID,
                price: newPrice,
                note: "业主主动调价"
            )
        )
        XCTAssertTrue(store.recordTimelineEvent(.delisted, for: listingID))

        let restored = PropertyStore(defaults: defaults)
        let listing = restored.listings.first { $0.id == listingID }
        XCTAssertEqual(listing?.totalPrice ?? .nan, newPrice, accuracy: 0.001)
        XCTAssertEqual(listing?.availability, .delisted)
        XCTAssertEqual(listing?.timeline?.last?.kind, .delisted)
        XCTAssertTrue(
            listing?.timeline?.contains {
                $0.kind == .priceChanged && $0.detail.contains("业主主动调价")
            } == true
        )
    }

    @MainActor
    func testPropertyEditsAndMediaAttachmentsPersist() {
        let suiteName = "HuJuPropertyEditingTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PropertyStore(defaults: defaults, loadsSampleData: true)
        var listing = store.listings[0]
        listing.name = "修改后的房源"
        listing.highlights = ["客厅采光稳定"]
        listing.concerns = ["夜间噪音待确认"]
        store.update(listing)
        store.addMediaAttachment(
            PropertyMediaAttachment(
                id: UUID(),
                kind: .photo,
                fileName: "现场照片.jpg",
                createdAt: .now
            ),
            for: listing.id
        )

        let restored = PropertyStore(defaults: defaults)
        let saved = restored.listings.first { $0.id == listing.id }
        XCTAssertEqual(saved?.name, "修改后的房源")
        XCTAssertEqual(saved?.highlights, ["客厅采光稳定"])
        XCTAssertEqual(saved?.concerns, ["夜间噪音待确认"])
        XCTAssertEqual(saved?.mediaAttachments?.first?.kind, .photo)
        XCTAssertEqual(saved?.mediaAttachments?.first?.fileName, "现场照片.jpg")
    }

    @MainActor
    func testPropertyUnitIdentityDistinguishesHomesInSameCommunity() {
        var first = PropertyStore.samples[0]
        var second = PropertyStore.samples[0]
        first.unitLabel = "80 平方米南向两房"
        first.building = "12 号楼"
        first.floorDescription = "中楼层"
        second.unitLabel = "95 平方米三房"
        second.building = "8 号楼"
        second.floorDescription = "高楼层"

        XCTAssertNotEqual(first.resolvedUnitLabel, second.resolvedUnitLabel)
        XCTAssertNotEqual(first.locationSummary, second.locationSummary)
    }
}
