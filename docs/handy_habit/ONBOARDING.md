# Onboarding

Source: `welcome/welcome_page.dart`, `story_scene.dart`, `practice_today.dart`,
`motion.dart` (the beats, Highlighted, Spotlight and PhoneFrame of Handy Boards
and Handy Bookmark, in Habit's colours), first-launch routing in `app.dart`.
Tests: `run5_learning_test.dart`, `run16_release_test.dart`. Shots:
`SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart --plain-name welcome`.

| Stage | Experience | Action |
| --- | --- | --- |
| Story, two beats | A sticky note, a message and a calendar page lie about (they rise in one by one); on the button each flies into a row of Today, becomes a bead string, the beads pop in and the kept ring closes to two of three. No question | Bring them into today, then Show me how |
| Practice | A pretend Today at real size under a Spotlight: tap Read's bead, fill Water to 3 of 3, start a one-step routine, finish it. The ring closes; a check badge says Today is all done | Each action or Do it for me advances; Next after practice |
| A missed day | A week of reading: beads arrive one by one, the hollow one is labelled missed, 86% counts up; the streak line stays | One Start button (Done on replay) |

The bar has three segments. The first beat has no Back (Skip only); Back, Esc and
Android back step back a beat or a stage, leaving the practice restarts it. Enter
presses the button (in the practice it does the step). Completion saves only
`onboarded`; a failed save shows a retry notice. Replay from Settings or How to
use pops without changing data. Everything moves on one 1.5 s clock per stage;
with reduced motion every picture is shown finished.

Headlines are 30 logical px on phones and 44 on wide screens (700 px), Nunito
800 in the oxblood anchor with the key words on a tint band. Pictures are
fixed-size drawings scaled to fit, so large text never cuts them.
