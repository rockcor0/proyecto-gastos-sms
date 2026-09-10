# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iOS app (SwiftUI, iOS 17+), bundle id `com.ridel007.gastossms`. Displays on-device as **Mecateando** (`CFBundleDisplayName` in `project.yml`) — the Xcode project/target/module name, scheme, and every internal reference (including `@testable import GastosSMS` in tests) are still **GastosSMS**; that's a deliberate split between the user-facing name and the technical identifiers, not an inconsistency to "fix". Tracks monthly expenses, either entered manually or parsed from pasted bank/wallet SMS text (Colombian banks — no automatic SMS capture yet, see "SMS capture roadmap" below).

## Project generation (XcodeGen)

The Xcode project (`GastosSMS.xcodeproj`) is **generated, not committed** — `project.yml` is the source of truth. After cloning, or any time `project.yml` or the file layout under `Sources/`/`Tests/` changes, regenerate it:

```sh
xcodegen generate
```

XcodeGen is installed via Homebrew (`brew install xcodegen`).

## Build & test

Building/testing from the CLI requires `xcode-select` to point at full Xcode, not just the Command Line Tools:

```sh
xcode-select -p   # should print .../Xcode.app/Contents/Developer
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer  # if not
```

Then:

```sh
xcodebuild -project GastosSMS.xcodeproj -scheme GastosSMS -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -project GastosSMS.xcodeproj -scheme GastosSMS -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Or open `GastosSMS.xcodeproj` in Xcode and build/run/test from there (⌘R / ⌘U).

## Architecture

- `Sources/GastosSMS/App/GastosSMSApp.swift` — SwiftUI `@main` app entry point; owns the SwiftData `.modelContainer(for: Transaction.self)`.
- `Sources/GastosSMS/Models/Transaction.swift` — SwiftData `@Model` for a single expense/income movement. `Transaction` does not declare `: Identifiable` explicitly — `PersistentModel` already conforms, satisfied by the `id: UUID` property.
- `Sources/GastosSMS/Models/TransactionEnums.swift` — `MovementType`, `Currency`, `CaptureSource` (all `String`-backed, `Codable`, `CaseIterable`).
- `Sources/GastosSMS/Parsing/SMSParsingEngine.swift` — regex/keyword-based rule engine that extracts bank, movement type, amount, currency, merchant and payment method from raw Colombian bank SMS text. Patterns are still mostly generic heuristics, not verified per-bank templates — see the doc comment at the top of the file before trusting exact wording. Bank/type/currency detection uses `String.range(of:options:[.caseInsensitive, .diacriticInsensitive])`; only amount/merchant/card extraction use `NSRegularExpression` (which has no diacritic-insensitive option, unlike `String.CompareOptions`). `extractAmount` has 3 fallback patterns in order: `$`/`COP`-prefixed, `pesos`/`COP`-suffixed, then `amountBareRegex` (a bare Colombian-formatted number with no currency marker at all) — added after a real Banco Caja Social message ("Su pago por 2.119.221,76 para...") turned out to have neither a symbol nor "pesos"/"COP".
- `Sources/GastosSMS/Parsing/ParsedTransaction.swift` — output struct of the parsing engine, with a computed `needsReview` (low confidence or missing amount).
- `Sources/GastosSMS/Parsing/GenerativeTransactionCandidate.swift` / `GenerativeExtractionService.swift` — the "Capa 2" generative fallback: Apple's on-device Foundation Models framework (`@Generable`/`@Guide`, `LanguageModelSession`), used only when `SMSParsingEngine` leaves `needsReview == true`. **Requires iOS 26.0** (far above this project's iOS 17+ deployment target) — every entry point is `@available(iOS 26.0, *)` and every call site is guarded with `if #available`, so the app must keep working identically on older iOS/devices without Apple Intelligence. `GenerativeExtractionService.refine` never throws to its caller — on any failure or unavailability it returns the input `ParsedTransaction` unchanged. The rule engine's own findings always win in the merge; the generative pass only fills fields the rules left empty. `refine` also accepts `[CorrectionExampleSnapshot]` — past user-confirmed transactions from the same bank — injected into the prompt as few-shot guidance; this is the only "learning" mechanism in place today (there is no public API to retrain the on-device model itself, see the GastosSMS generative-AI analysis).
- `Sources/GastosSMS/Models/CorrectionExample.swift` — SwiftData `@Model` storing a confirmed SMS-derived transaction (raw text + final values) keyed by bank, written by `TransactionEditorView.recordCorrectionExampleIfNeeded` on every save that has both a bank and raw text, and read by `PasteSMSView.recentExamples(forBank:)` (most recent 3) to build the few-shot prompt above. Registered in the app's `modelContainer` alongside `Transaction`.
- `Sources/GastosSMS/Support/CurrencyFormatting.swift` — `es_CO`-locale currency formatting (0 decimals for COP, 2 for USD).
- `Sources/GastosSMS/Support/YearMonth.swift` — a plain year+month value type (not `Date`) used to represent "the month being viewed", with `.current`/`.previous`/`.next` and a `dateInterval(calendar:)` for filtering `Transaction.date`. Exists because comparing bare `Date`s via `Calendar.isDate(_:equalTo:toGranularity:)` doesn't generalize to "the user is browsing a past month" — see the GastosSMS monthly-navigation-and-achievements analysis.
- `Sources/GastosSMS/Support/SpendingTrend.swift` — compares `selectedMonth`'s total against `selectedMonth.previous`'s (0 if that month has no transactions). `difference = previousTotal - currentTotal`; positive is `.better` (spent less — green up arrow), negative is `.worse` (spent more — red down arrow), zero is `.same`. This is also the "ahorro" figure the planned achievements/points phase will consume — see the analysis.
- `Sources/GastosSMS/Views/ContentView.swift` — main dashboard, scoped to `@State private var selectedMonth: YearMonth` (defaults to `.current`): total, transaction list, and swipe-to-delete are all filtered to that month via `selectedMonthTransactions`. ← → buttons in `summaryCard` move `selectedMonth`; the → button disables once `selectedMonth >= .current` (no browsing into the future). `trendIndicator` shows `SpendingTrend` right under the total. Also has the "+" menu (manual entry / paste SMS), tap-to-edit.
- `Sources/GastosSMS/Views/TransactionEditorView.swift` — shared form for create/edit, driven by `TransactionDraft` (built from scratch, from a `ParsedTransaction`, or from an existing `Transaction`). Amount parsing tries the device's current locale first (so a `,` decimal from `.decimalPad` in Spanish locales works), falling back to `en_US_POSIX`.
- `Sources/GastosSMS/Views/PasteSMSView.swift` — paste/type raw SMS text; runs it through `SMSParsingEngine`, then (async, iOS 26+ only, if still `needsReview`) through `GenerativeExtractionService`, then hands the result to `TransactionEditorView` for confirmation before saving. Always sets `TransactionDraft.aiNote` explaining what happened — whether the model ran, why it didn't (unsupported iOS, or `SystemLanguageModel.default.availability != .available`, which is the common case in the iOS Simulator — Foundation Models generally needs a physical device), and, when it did run, `GenerativeRefinementResult.summary` / `GenerativeTransactionCandidate.fieldSummary` — every field the model returned verbatim, before any merging or `Decimal` parsing — shown in the confirmation form so a miss is diagnosable (model didn't find the field vs. found it but `merged(into:rawText:)` failed to parse it) instead of a silent black box.
- `Sources/GastosSMS/Views/TransactionRowView.swift` — list row.
- `Sources/GastosSMS/Resources/Assets.xcassets` — app icon, accent color, and other asset catalog entries.
- `Sources/GastosSMS/Preview Content/` — assets available only to SwiftUI previews (`DEVELOPMENT_ASSET_PATHS`), not shipped in the app.
- `Tests/GastosSMSTests/SMSParsingEngineTests.swift` — unit tests for the parsing engine (amount normalization, bank/type detection, missing-field handling).
- `Tests/GastosSMSTests/` — unit test target (`GastosSMSTests`), depends on the `GastosSMS` app target via `@testable import`.

## SMS capture roadmap

Only manual entry and paste-to-parse exist today ("Fase 0" of the product roadmap). iOS has no public API to read a device's existing SMS history, and there is no way to fetch new messages on app launch either — the only real capture hook is the `IdentityLookup` Message Filter Extension, which sees a message's text at the moment it arrives and requires an Apple-approved entitlement plus the user enabling it in Settings. That capture path (a separate Xcode extension target, an App Group shared container, and background processing via `BGTaskScheduler`) is deliberately out of scope until a later phase — nothing here should assume it exists.
