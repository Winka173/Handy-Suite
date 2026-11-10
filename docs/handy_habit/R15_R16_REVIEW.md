# R15/R16 host review — 2026-11-10

Contract was added to Habit's own section of `docs/UX_REDESIGN.md` before code.
Applied the requested design-taste app-screen and frontend UI engineering skills,
plus the targeted UI/UX error-recovery guidance. Existing editorial/Nunito face,
owned palette and bead identity remain the design context. Sync itself is a quiet
settings surface, with no new decorative signature or cloud illustration.

Inventory: personal Android account, optional Free opt-in, 0 or more pending
operations, last successful time, five recent successes, last error and retained
conflict candidates. The person asks whether devices are in step; the status is
the first finding. Turn on / Sync now is the sole primary action. Settings/Data
navigation is separate from backup. Back returns to Settings.

First render: `apps/handy_habit/build/run9-sync-pass1`, 432 real-widget PNGs.
24 combinations (EN/VI × light/dark × 320/390/1440 × text1/1.5), six states each
(off, connecting, synced, pending, error, newer-remote), top/detail/privacy views.

Critique: status is largest and first; all content shares the same 720px maximum
measure and phone gutters. No KPI tiles, rainbow icons or empty decorative bands.
At 320/150%, long Vietnamese refusal wraps and the primary action remains reachable;
the rest scrolls. Account/error/privacy text stays readable; narrow action rows
wrap. Missing account/time have words rather than invented values. Text scale is
not reduced. Tone and type match the existing Habit Settings.

Fixes after first render: singular “1 operation”/“1 successful sync” wording;
renamed user-facing pending units to changes, off state names itself instead of
pretending to queue; added persistent Last error including None and a clear build
configuration error. Re-rendered the complete same matrix into
`apps/handy_habit/build/run9-sync-final` (432 PNGs, all 24 tests pass). Privacy and
detail continuations show content below the phone viewport. No RenderFlex overflow.
Screen-reader state/error live regions and native buttons/selectable facts are
implemented; device TalkBack/VoiceOver and actual account-picker UI are unverified.

Representative final shots:
- `390-en-light-100-synced-top.png`
- `320-vi-dark-150-newerRemote-top.png`
- `1440-en-light-100-off-top.png`
- `320-vi-light-150-error-privacy.png`

Source tests cover gate-off Settings, Android-only gate, route/back, enable/off and
explicit mood conflict review. Engine/controller/HTTP tests cover causal union,
convergence, failures, immutable generations, retries and account disconnect.
No device, keystore, external account or other app was accessed.
