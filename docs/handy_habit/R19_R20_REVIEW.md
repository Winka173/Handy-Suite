# R19/R20 + Pro structure · run13 · 2026-11-11

Implemented in Habit app/engine only; schema8 / physical2 / protocol1 unchanged. Single agent. No git writes, devices, secrets, sibling-source reads or shared edits. One unavoidable shared-source read: handy_ui/kit/app.dart wrap/theme placement for current-entitlement styling. Saved run12 sibling rasters are the structural references.

## Pro page

Large headline and sentence, selected live demo first, replay/other-case controls, selected description, Routines / Understand / Make it yours sections with drawn thumbnails/title/summary/play, pinned Restore/Get Pro with store-supplied price. Loading/pending/owned/cancel/error/unavailable/restore/not-found/offline-owned/unsupported/unconfigured remain honest. Twenty-five existing Pro tests cover purchase states/gates/draft/reduced motion. All host store responses are synthetic. Supervisor reports Play product handy_habit_pro active at99,000 VND and draft1.0.0(2); this run verifies no store transaction.

## Insight counting and choices

- Month/quarter compare equal elapsed civil days, clamping shorter prior periods and exposing exact dates. Only closed days/full weeks; exclusions inherit the engine. Percent deltas subtract displayed rounded percentages. Each daily/weekly opportunity counts once.
- Group rates sum kept/eligible opportunities, never average habit percentages. Current collection or explicit day part, then earliest enabled reminder/linked routine, never claimed historic check-in time.
- Difficulty: fewer than7 eligible means learning; ≥80% steady; ≥50% building; otherwise stretch. Misses=eligible−kept. Weekday figures use eligible daily goals only, never allocate weekly quotas to weekdays.
- Suggestions use10 comparable daily opportunities within28 days under the current target: ≥9 kept suggests+25%, ≤5 suggests−25%, rounded to whole displayed units. Amounts/minutes use thousandths. Binary/negative/weekly and pending future schedules excluded. Accept/dismiss persists; stale offers refuse; accepted schedule starts tomorrow with old history intact. Current Pro checked at mutation.
- Mood co-occurrence uses recorded1–5 ratings on eligible closed daily days, requires14 pairs and3 per group, excludes disputed/deleted/unknown/paused observations. Counts and means shown; no causation/medical inference.
- Collection/time/direction/weekday/outcome filters compose without changing data. Weekly heat cells repeat whole-week outcomes, explicitly explained. Free Progress/heatmap/export/mood history stay free; free smart page uses labelled disposable history.
- Designed A4 Nunito PDF has branded header, sections, methods/counts and page footer. Preview and PDF consume the same evidence. Explicit save warns of private habit/mood summaries, supports cancel/retry and checks current Pro. Actual EN/VI PDFs generated and raster-inspected, text extracted independently with PyMuPDF.

## Studio

Three owned palettes (Vermilion/Grove/Ochre), independently defined light/dark; six AA contrast cases cover text/actions/controls. Today open rows/framed cards and everyday/airy spacing, six existing Material outline icons, progress-track/quiet runner. Selected habit preview preserves identity hue. Everyone previews, Cancel/back writes nothing, Pro applies. Snapshot captured on entry protects newer settings; failed/stale writes keep draft and inline recovery copy. Loss uses free look while keeping choices; regrant reactivates them. Basic appearance stays free. Android widget source only supports fixed layout/system day-night colors; no custom widget control is advertised.

## Evidence and limits

App247 tests and engine191 tests passed. New app17 cases include six contrast cases, glyph coverage, apply/cancel/refund/regrant, failed/stale persistence, runner and PDF gating; new engine16 cases cover figures, windows, denominators, pauses/skips/unknowns/negative/weekly/DST and settings roundtrip. Format/analyze clean in both packages. Debug APK with HANDY_DRIVE_SYNC=true built successfully; Gradle cache set to writable C:/Users/Winka/.gradle. Build only, never installed.

`apps/handy_habit/build/run13/`: round1=624 PNGs, final=672 PNGs (24 combinations ×28 scenes), six priority and24 matrix sheets, index.html/inventory.json, test/analyze/build logs, actual bilingual PDFs and first-page PNGs. EN/VI ×light/dark ×320/390/1440 ×text1/1.5. Final fixture adds an evening Walking habit for two-group comparisons. Screens reviewed, glyph/order/thumbnail/preview fixes re-rendered. No synthetic figure is presented as a user's history.

Eleven files in docs/qa/evidence/habit-export restored byte-for-byte to run13b-start originals after tests; export-restoration.json records hash equality. Existing unrelated working-tree changes remain intact.

Remaining: real Play licence-test purchase/restore/refund/offline-restart, OS/launcher/screen-reader/keyboard/browser and large real histories. No iOS/Windows/Web checkout or custom widget appearance. Shared K1–K4 from run11 remain supervisor work. Pro listing may include advanced routine conditions/choices/dependencies/stacking/day durations/blocks/presets; smart comparisons/patterns/goals/mood/filters/PDF; studio palettes/cards/icons/runner; removal of supported ads.

## App-screens §2.7 critique

1. First reading order answers the question: selected Pro demo; compared periods/counts; studio draft preview. Nunito and Habit's bead vocabulary carry the existing direction; no new style draw/redraw was needed for this constrained continuation.
2. Shared edges use bounded columns and16px phone gutters; desktop studio pairs preview/choices without stretching their heights. Heatmap trailing cells preserve chronology rather than invent filler.
3. Owned palette is visible; hue carries kept data/selection, misses stay neutral. No tinted KPI icon boxes, gradients, decorative charts or oversized vanity figures.
4. Final two-habit fixture: January12/14=86%, prior11/14=79%, displayed delta+7pp; 28-day Morning25/28=89%, Evening20/28=71%. Goal9/10 at6 suggests8. Repeated counts, PDF sections and tooltips derive from the same engine; every comparison names dates/baseline. No sum of rounded habit percentages.
5. Empty evidence has0 eligible and no fabricated percentage; absent heat evidence uses a dash, mood reports pair sizes/insufficient evidence. Pro badges label capabilities, never a fictitious work queue.
6. Kept heat fractions match their marks; neutral/hollow states are explained in copy/semantics. Period bars have their period label; no legend mismatch or clipped chart labels was found in inspected renders.
7. Phone pages retain native Back and scrolling; 320/text1.5 reflows descriptions/controls/footer. Desktop is bounded; previews, filters, PDFs and actions remain reachable. Host matrix passes; physical keyboard/SR/browser remain unverified.
