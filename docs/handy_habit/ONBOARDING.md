# Onboarding

Source: `welcome/welcome_page.dart`, `practice.dart`, `practice_today.dart`,
`scenes.dart`, first-launch routing in `app.dart`. Tests: `run5_learning_test.dart`,
`run11_consistency_test.dart`, `run16_release_test.dart`.

| Stage | Experience | Action |
| --- | --- | --- |
| Story, two beats | Scattered intentions become daily bead strings; local-first explanation; no purpose question | Bring them into today, then Show me how |
| Practice | Pretend Today: check in, Undo, water goal 3→8, start tiny routine, finish reading step, see ring/bead fill | Each action or Do it for me advances; Next after practice |
| One more idea | Hollow bead is a day, not failure; current/best streak and consistency tell a longer story | One Start button, no picker |

Progress, Back and Skip persist throughout. Esc/Android Back step back; Enter uses
the stage action. Busy completion blocks repeats and errors offer retry. Completion
persists onboarded; returning libraries are not forced through practice on update.
Replay from Settings/How to use pops without real data changes. Optional starters
belong to empty Today after the guide. Notification permission is contextual only.

Stage headlines use 30 Flutter logical pixels on phones, 44 on wide screens
(breakpoint 900). Phone practice now follows that contract too. Story/final were
already correct without a density divisor/clamp. At density 2.6, the 30-logical-pixel
em is 78 physical pixels; visible Nunito ink is shorter than the em. Accessibility
text scaling remains active. Regression tests inspect RenderParagraph size and
transform at 1080×2400/density 2.6 and 3. Compact/large-text practice scrolls;
wide layout splits words/scene and footer actions stay available.

R27 host review: EN/VI × light/dark ×320/415/1440 ×text1/1.5, four scenes each.
Previous binary guide startup on two BlueStacks Android 11 instances is supervisor
reported. Final physical-density/OS back/screen reader/haptics and fresh/update/
replay checks remain with the supervisor. Practice never seeds the real library.
