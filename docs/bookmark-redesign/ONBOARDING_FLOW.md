# Handy Bookmark: the first-run guide (version 2)

This is version 2, written on 2026-11-06 after the owner reviewed version 1 on BlueStacks. The
owner judged version 1 too plain next to Tuckii: grey and black, text-only cards, faint motion,
and a form where a rehearsal should be. They decided:

- **no character**;
- **real, licensed photographs** for the samples;
- **practice on a simulated phone only**, as Tuckii does: nothing typed during the guide is
  saved.

What Tuckii does is recorded in `TUCKII_OBSERVATION.md`. None of its art, wording, mascot or
screen composition is used.

## The question and the finding

- Question: "How do I keep things here, and how do I get them back?"
- Finding, on the find step: "Type a few letters, accents optional; tap to open the original."

## Look

- **Colour:** the app's teal `#0E7490` is used fully here, on the primary button, the progress
  bar, the glow rings, the coach labels and the success check, with its pale tint `#D7EEF3` as a
  band under each title's key words. The ground is the brand's warm paper. Source labels carry
  each platform's own colour, as a name and never a logo.
- **Type:** Newsreader titles (46 px wide, 32 px on phones), Geist body text, and buttons taken
  from the theme's label style.
- **Objects:** cards are white with a 16 px radius and a soft shadow, because they float. Photos
  have a 10 px radius. The pretend phone is a dark frame with a 48 px radius.
- **Photographs:** five open-licence photos (bún chả, phở, guitars, Ga Hà Nội, Hội An lanterns),
  resized to 720 px with EXIF dropped. Two others were rejected because brand logos dominate
  them. Credits are in `apps/handy_bookmark/assets/welcome/CREDITS.txt` and in Settings ›
  Licenses.

## Flow

The progress bar has five segments, or four where the device has no notifications. Back and Skip
are on every step.

1. **"Saved all over the place."** Four photo cards (TikTok, Facebook, YouTube, Photos) fly in
   one after another with an overshoot and land scattered. A search pill reads "train
   timetable… · 0 results", and the cards fade to grey. Primary: **Bring it together**. Below
   it: **I have links in another app**, which opens import.
2. **"One place for all of it."** The same cards travel, in colour, into a Handy Bookmark library
   (name, All / Links / Pictures chips, two collections) and settle in a grid. This uses one
   scene widget across both steps, so the cards really move. Primary: **Show me how**.
3. **"Try saving a video."** A pretend phone shows a phở video. Each stage lights one thing, with
   a coach label beside it:
   - **Share** has a breathing ring and the label "Tap Share";
   - the share row slides up, the screen dims, and Handy Bookmark is ringed;
   - Handy Bookmark's save sheet appears: preview, "Put it in" with four collections, "Pick
     this" on Good food;
   - Save starts disabled. Once a collection is chosen it is ringed, with "Now tap Save";
   - a check pops (elastic) with an expanding ring: "Saved to Good food · Title, picture and
     source filled in", with a haptic tap.

   The button appears only after the save. The text then says it was practice and that nothing
   was saved.

4. **"Find it in a moment."** On the pretend phone a search types "pho bo" without accents. The
   key just typed lights on a drawn keyboard, the list narrows to the phở save, and "Open in
   TikTok" grows in.
5. **"A gentle weekly nudge?"** Phones only. A lock screen over the Hội An photo, 19:00 Sunday,
   and a notification drops in: "5 things you saved recently are still waiting." **Turn on the
   nudge** asks for permission and turns on the weekly nudge setting. **Not now** finishes.

## Motion

- One clock per step, 1.5 s, restarted on every step.
- Parts arrive in order:
  - the title rises with a soft overshoot (0–35 %);
  - the tint band draws in under the key words (30–70 %);
  - the body follows (12–50 %);
  - the button scales in last (60–95 %).
- Glow rings breathe on a 1.3 s loop around the next thing to tap.
- Under the system's reduce-motion setting everything is at rest at once: rings are still,
  cards sit in place, and buttons are there immediately.

## Layout

- **Under 700 px:** the progress bar, then the scene (52 % of the height, 220–560 px), then the
  title, body and a full-width 56 px button. The page scrolls when large text needs more room.
- **700 px and up:** words and buttons on the left (flex 5), the scene on the right (flex 6),
  with content at most 1180 px wide. The pretend phone keeps its own size; the reader's text
  size applies outside it, never inside the drawn phone.

## When it shows, and what it keeps

- It opens on start only on an empty library that never finished the guide (`guideDone` in the
  library preferences). It can be replayed from Settings › Help › How to save, or at
  `/welcome`.
- It saves nothing. The only thing it can change is the weekly nudge setting, and only when the
  person turns it on.

## Platform behaviour

- Android back and Esc go to the previous step; on step 1 they leave.
- Enter triggers the step's primary button once it is shown.
- iOS swipe-back leaves the guide.
- The nudge step appears only where the reminders plug-in is supported (Android and iOS), never
  on Windows or the web.

## Accessibility

- Titles are headers. The progress bar reads "Step n of N".
- The pretend phone in the practice step is interactive, and each target has a label (Share,
  Handy Bookmark, Good food, Save). The other scenes are pictures and are hidden from screen
  readers.
- Skip is always available.

## Rejected

Tuckii's mascot, art and wording; a paywall; a character of our own (the owner chose not to);
drawn illustrations instead of photos (the owner chose photos); saving during the guide (the
owner chose practice only); photos where a brand logo dominates.

## Checked

- `test/welcome_test.dart` (8 tests):
  - Skip is remembered;
  - existing libraries are never guided;
  - the practice keeps its order (Save stays disabled until a collection is picked) and saves
    nothing;
  - back;
  - replay from Settings;
  - no overflow at 320 px with text at 200 %, at 390 px, and at 1280 px.
- Screenshots of every stage at 390, 320 and 1280 px were rendered and reviewed. The dim behind
  the sheets was measured: brightness 107 drops to 48.
- The guide was run end to end on BlueStacks (Android 11) by tapping over adb. That is an
  emulator, not a phone.
