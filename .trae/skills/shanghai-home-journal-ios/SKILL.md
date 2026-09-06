---
name: "shanghai-home-journal-ios"
description: "Builds and reviews the 选个家 nationwide home-buying journal. Invoke for product, SwiftUI, MapKit, budget, AI-adviser, or buying-workflow changes in this repository."
---

# 选个家 iOS Product Skill

Use this skill for every product or implementation change in this repository.
Also load the installed `ios-swift` skill before editing Swift code.

## Product Contract

选个家 is a private decision workspace for home buyers across China. It is not a
listing marketplace and must not claim to provide official valuation, legal,
school-admission, lending, or tax advice.

The primary user loop is:

1. Define budget, cash, commute anchors, and non-negotiables.
2. Select a city and research no more than three districts or submarkets at a time.
3. Record structured evidence during every viewing.
4. Compare properties using observed facts and explicit preferences.
5. Close evidence gaps before adding more candidates.
6. Archive the reasons for choosing or rejecting final candidates.

Read `docs/market-analysis.md` before changing positioning or feature scope.

## Experience Principles

- Start with the usable decision workspace, never a marketing landing page.
- Keep the map and viewing journal as first-class navigation destinations.
- Make important actions reachable with one hand and obvious without help text.
- Use SF Symbols for controls and keep card corner radii at 8 points or less.
- Use a neutral base with green, coral, blue, and yellow as semantic accents.
- Preserve Dynamic Type, VoiceOver labels, 44-point tap targets, and dark-mode
  legibility when extending the interface.
- Treat a property as a body of evidence, not a promotional listing.

## AI Rules

- Separate facts, user notes, inference, and missing evidence.
- Explain every score with visible reasons.
- Ask for missing evidence instead of inventing it.
- Show data freshness for market and policy information.
- Keep `AIAdvising` as the integration boundary. A remote or on-device model can
  replace `LocalAIAdvisor` without changing view code.
- Never send property notes, addresses, income, or identity data to a remote model
  without explicit consent and a privacy disclosure.

## Swift Implementation

- Use SwiftUI and `NavigationStack`.
- Keep user-facing state on `@MainActor`.
- Persist Codable user data locally unless a sync requirement is explicitly approved.
- Put scoring and financial formulas in pure types with unit tests.
- Avoid force unwraps except fixed UUID literals in sample-only data.
- Do not add third-party dependencies for capabilities available in Apple frameworks.

## Required Verification

Run:

```bash
xcodebuild \
  -project HuJu.xcodeproj \
  -scheme HuJu \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Then run unit tests on an available iPhone simulator. For UI changes, capture at
least one current iPhone screenshot and inspect it for clipping, overlap, empty map
content, illegible text, and broken safe-area behavior.

## Definition Of Done

- The app builds without warnings introduced by the change.
- Budget and ranking logic have assertions.
- Policy claims include a date and authoritative source.
- AI output exposes reasons and missing checks.
- Map, journal, and market analysis remain functional.
- README screenshots and scope notes are updated for major UI changes.
