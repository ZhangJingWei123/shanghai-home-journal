import XCTest
@testable import HuJu

final class HuJuTests: XCTestCase {
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

    func testArchivedPropertyIsNotRecommended() {
        let archived = PropertyStore.samples.last!

        let result = LocalAIAdvisor().recommendations(
            listings: [archived],
            profile: BudgetProfile()
        )

        XCTAssertTrue(result.isEmpty)
    }
}
