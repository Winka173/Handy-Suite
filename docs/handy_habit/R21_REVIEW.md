# R21 / run12 review — 2026-11-10

The contract was added to Habit's `UX_REDESIGN.md` section before code. The two
mandatory UI skills guided the screen inventory, questions, responsive states and
critique. Habit keeps Nunito, its editorial greeting and bead signature, vermilion,
oxblood and ochre. The owner's explicit sibling-style Help icon squares override
the taste skill's general prohibition on repeated icon containers.

## What changed

Help now opens with the tinted Replay introduction card, followed by search and
Topics. Every topic has an icon in a soft square, title, short summary and chevron;
search results have no numbering. Full drawn examples stay in topic details.
The Today shell and wide sidebar use the actual app asset. Today and Routines share
a contextual, labelled floating creation action; the old inline routine button is
removed, the secondary Add menu retains its paths, and lists reserve bottom space.
Progress, Settings and pushed pages retain their destination/title/back mechanics.

The Pro page presents nine shipped Advanced routine capabilities. Demos run disposable
engine plans: weekday/unfinished/time rules, A/B choice, dependency, stacking,
weekday durations, block insertion and preset replacement. They never write to the
controller. Feature badges open the matching stage; returning to the builder keeps
the draft and updates entitlement-dependent controls. Free tracking, negative habits,
basic routines/runner, templates, core Progress/heatmap, mood, export and all data
ownership features remain free. Saved Advanced plans remain runnable. R19 insights
and R20 studio are still open and labelled as planned later, outside current benefits.

## Purchase authority and configuration

Habit already used `HandyApp(app: 'habit')`, the same composition as Boards. That
installs `MonetizationHost`, `LifetimeController` and the real `NativeLifetimeStore`.
`HANDY_MONETIZATION_CONFIG` supplies `habit.android.productId` and optional
`habit.android.androidPublicKey`; configured ads use `adsEnabled`/`bannerAdUnitId`.
No local config or define file was read. No product or price is hardcoded in app code.
The supervisor's intended product is `handy_habit_pro`, one-time, with its configured
regional price; all displayed purchase prices come from the store snapshot.

`handy_store` is now a normal dependency. One unavoidable shared change is confined
to Android `HandyStorePlugin.kt`: after an authoritative empty ownership query,
read/restore also query one-time product details and return the localized price.
This follows the official [Play Billing integration API](https://developer.android.com/google/play/billing/integrate#show-products).
It never launches a billing flow. Buy still queries fresh details before checkout.
Existing ownership/signature checks, acknowledgement and device-bound encrypted proof
cache are retained; a successful empty ownership query clears refunded ownership,
while store failure can retain previously verified cache. No entitlement is exported
with user data. No server receipt validation was added.

Buy requires a loaded price and no busy/pending operation. Restore, retry, cancellation,
pending, error, unavailable, restored/not-found and cached offline-owner states are
explicit. Error copy does not promise that an uncertain payment was never charged.
Pro removes the shared configured ad slot. Web, Windows and iOS show the page with
unavailable-platform copy and no checkout controls. No mock store ships in `lib/`;
the optional test injection and synthetic adapter exist solely for host verification.

## Visual critique and corrections

Question and hierarchy: Help answers how to perform a job through readable summaries;
Today still leads with kept/due and a one-tap bead; Pro leads with the selected live
capability and the purchase panel follows it. Feature rows, Free comparison and planned
work are below. At 320/text1.5 the page scrolls instead of pinning an oversized footer.

The first raster review exposed an undecoded mark in the test screenshot, inherited
black/white FAB styling, and purchase-state screenshots scrolled past their status.
The renderer now precaches the mark and anchors each state on the purchase panel;
the FAB uses Habit's anchor/on-anchor colors. A reduced-motion demo initially forced
every interaction back to its final frame; it now starts there but remains interactive.
Block insertion retains draft steps, while preset loading replaces them. Purchased
state no longer offers an unnecessary price Retry. Topics now has heading semantics
and the filtered one-topic count uses singular English.
The wide Help index no longer reserves an empty article column: it centers at max720,
then expands to the max960 index/article layout only after a topic is chosen.

Fresh references run from each sibling's own directory, avoiding an imported renderer's
wrong asset bundle. A missing Manrope registration initially produced test-font blocks
in Bookmark; corrected reference captures use real text. No sibling source was changed.

Re-rendered evidence covers EN/VI × light/dark ×320/390/1440 ×text1/1.5: 24 Habit cases,
360 PNGs per full pass. Twelve Pro scenes cover overview/loading/price/pending/owned/
restore/not-found/error/unavailable/offline-owned/cancelled/unsupported. Settings Pro
is also captured. The siblings have 48 cases/144 PNGs. Six priority and 48 matrix sheets
combine actual host rasters, with originals linked from `build/run12/index.html`.
Host store states are labelled synthetic. No prices, diagrams or screenshots claim
to be a real Play transaction.

## Verification and supervisor work

App **230 tests** (25 new), engine **175**, shared store **1**, monetization **7** pass.
New tests cover purchase/restore/cancel/error/offline/pending/refund, duplicate actions,
foreign/unverified responses, price loading/absence, unconfigured and unsupported
platforms, ads removal, all demos/badges, draft retention, reduced motion, and Pro
accessibility at 320/text1.5 EN/VI light/dark. Existing engine and save-time Advanced
gate assertions remain. Format and analyze are clean in the app and engine.

Debug APK builds with `HANDY_DRIVE_SYNC=true`; merged manifest contains
`com.android.vending.BILLING`. Offline bootstrap was needed because network access
is restricted; Gradle uses the writable user cache. The existing `home_widget` KGP
migration warning is non-fatal. No release appbundle, browser, emulator, device or
real store transaction was run. Non-Android purchase runtime is not verified.

Supervisor: create the product after uploading a billing-enabled release bundle;
test local price, buy/cancel/pending, acknowledgement, restore/same account/reinstall,
refund/revocation, offline restart/cache and ad removal through Play licence testing.
Check device Back/IME/SR and actual account/store errors. Shared Android catalogue
lookup is backward compatible but affects sibling store reads, so include their Play
price smoke checks. R19/R20 and run11's shared K1–K4 follow-ups remain open.

Export evidence is restored byte-for-byte to its run12-start snapshot after tests;
those originals already differed from HEAD. No git writes or prohibited secret reads.
