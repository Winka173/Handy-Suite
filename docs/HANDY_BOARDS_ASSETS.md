# Handy Boards artwork and presets

Design contract, 2026-11-07: Covers help a person recognize a board or card without searching.
The host picker owns selection; CoverArt only renders art and an accessible localized name.
Known IDs render immediately offline; null and unknown IDs render a calm sage neutral composition.
There is no network, loading delay, animation, or raster failure state.

The existing Boards editorial workspace direction is retained: warm flat colour, cut paper silhouettes,
quiet drawing details, and Plus Jakarta Sans for review labels. The signature is a composed still life
or landscape, recognizable in both a short header and a gallery tile. All art stays as drawn in either theme.
The component fits the host's constraints at widths 320–1440 and beyond; it has no controls or navigation.
Reject neon, indigo/violet, glow, glass, decorative gradients, text inside art, and repeated recolours.
The app's screen contract remains Claude's responsibility; this document covers the isolated art component.

## Delivered catalog

60 distinct original procedural covers: 30 Free and 30 Pro. Each of the ten families has
six compositions, with its first three covers Free. The renderer contains a separately
authored scene for each ID, using a shared drawing vocabulary rather than a recolour scheme.
All names are supplied in English and Vietnamese. IDs are persistence keys and must remain renderable.

| Family | Total | Free | Pro |
| --- | ---: | ---: | ---: |
| study | 6 | 3 | 3 |
| work | 6 | 3 | 3 |
| goals | 6 | 3 | 3 |
| shopping | 6 | 3 | 3 |
| home | 6 | 3 | 3 |
| creative | 6 | 3 | 3 |
| travel | 6 | 3 | 3 |
| events | 6 | 3 | 3 |
| wellness | 6 | 3 | 3 |
| abstract | 6 | 3 | 3 |
| **Total** | **60** | **30** | **30** |

| Stable ID | English name | Vietnamese name | Access | Provenance |
| --- | --- | --- | --- | --- |
| `study.notebook-grid` | Notebook grid | Lưới vở | Free | original procedural |
| `study.open-book` | Open book | Trang sách mở | Free | original procedural |
| `study.pencil-case` | Pencil case | Hộp bút | Free | original procedural |
| `study.orbital-notes` | Orbital notes | Quỹ đạo kiến thức | Pro | original procedural |
| `study.library-steps` | Library steps | Bậc thềm thư viện | Pro | original procedural |
| `study.geometry-set` | Geometry set | Bộ thước hình học | Pro | original procedural |
| `work.folder-stack` | Folder stack | Chồng hồ sơ | Free | original procedural |
| `work.desk-light` | Desk light | Đèn bàn | Free | original procedural |
| `work.sticky-plan` | Sticky plan | Giấy ghi chú | Free | original procedural |
| `work.paper-clips` | Paper clips | Kẹp giấy | Pro | original procedural |
| `work.architect-desk` | Architect desk | Bàn kiến trúc | Pro | original procedural |
| `work.inbox-trays` | Inbox trays | Khay tài liệu | Pro | original procedural |
| `goals.summit-path` | Summit path | Đường lên đỉnh | Free | original procedural |
| `goals.stepping-stones` | Stepping stones | Từng bước tiến | Free | original procedural |
| `goals.growing-branch` | Growing branch | Cành non vươn lên | Free | original procedural |
| `goals.target-rings` | Target rings | Vòng tâm điểm | Pro | original procedural |
| `goals.milestone-flags` | Milestone flags | Cột mốc hành trình | Pro | original procedural |
| `goals.sunrise-stairs` | Sunrise stairs | Bậc thang bình minh | Pro | original procedural |
| `shopping.market-tote` | Market tote | Túi đi chợ | Free | original procedural |
| `shopping.wrapped-parcel` | Wrapped parcel | Gói quà nhỏ | Free | original procedural |
| `shopping.wish-shelf` | Wish shelf | Kệ đồ mong muốn | Free | original procedural |
| `shopping.ceramic-picks` | Ceramic picks | Gốm yêu thích | Pro | original procedural |
| `shopping.pantry-jars` | Pantry jars | Hũ đồ khô | Pro | original procedural |
| `shopping.fabric-swatches` | Fabric swatches | Mẫu vải | Pro | original procedural |
| `home.arched-window` | Arched window | Khung cửa vòm | Free | original procedural |
| `home.woven-linen` | Woven linen | Vải lanh dệt | Free | original procedural |
| `home.garden-tiles` | Garden tiles | Gạch sân vườn | Free | original procedural |
| `home.reading-corner` | Reading corner | Góc đọc sách | Pro | original procedural |
| `home.courtyard` | Courtyard | Sân trong | Pro | original procedural |
| `home.quilt-blocks` | Quilt blocks | Ô chăn ghép | Pro | original procedural |
| `creative.paper-collage` | Paper collage | Ghép giấy | Free | original procedural |
| `creative.paint-palette` | Paint palette | Bảng pha màu | Free | original procedural |
| `creative.cutout-garden` | Cutout garden | Vườn giấy cắt | Free | original procedural |
| `creative.ceramic-studio` | Ceramic studio | Xưởng gốm | Pro | original procedural |
| `creative.ribbon-weave` | Ribbon weave | Dải màu đan | Pro | original procedural |
| `creative.printing-blocks` | Printing blocks | Khuôn in | Pro | original procedural |
| `travel.coastal-route` | Coastal route | Cung đường ven biển | Free | original procedural |
| `travel.mountain-pass` | Mountain pass | Đèo núi | Free | original procedural |
| `travel.city-arches` | City arches | Vòm phố | Free | original procedural |
| `travel.folded-map` | Folded map | Bản đồ gấp | Pro | original procedural |
| `travel.night-train` | Night train | Chuyến tàu đêm | Pro | original procedural |
| `travel.island-harbour` | Island harbour | Bến đảo | Pro | original procedural |
| `events.ticket-pair` | Ticket pair | Đôi vé | Free | original procedural |
| `events.garden-table` | Garden table | Bàn tiệc ngoài vườn | Free | original procedural |
| `events.paper-lanterns` | Paper lanterns | Đèn lồng giấy | Free | original procedural |
| `events.confetti-cutouts` | Confetti cutouts | Giấy màu ngày vui | Pro | original procedural |
| `events.ribbon-invite` | Ribbon invite | Thiệp thắt nơ | Pro | original procedural |
| `events.stage-curtain` | Stage curtain | Rèm sân khấu | Pro | original procedural |
| `wellness.quiet-waves` | Quiet waves | Sóng êm | Free | original procedural |
| `wellness.morning-leaves` | Morning leaves | Lá sớm mai | Free | original procedural |
| `wellness.tea-ritual` | Tea ritual | Một tách trà | Free | original procedural |
| `wellness.pebble-balance` | Pebble balance | Đá cân bằng | Pro | original procedural |
| `wellness.breathing-orbits` | Breathing orbits | Nhịp thở tròn | Pro | original procedural |
| `wellness.sun-salutation` | Sun salutation | Đón nắng | Pro | original procedural |
| `abstract.balanced-forms` | Balanced forms | Hình khối cân bằng | Free | original procedural |
| `abstract.split-circle` | Split circle | Vòng tròn chia đôi | Free | original procedural |
| `abstract.terrace-lines` | Terrace lines | Đường bậc thềm | Free | original procedural |
| `abstract.folded-rhythm` | Folded rhythm | Nhịp gấp | Pro | original procedural |
| `abstract.sculpted-arches` | Sculpted arches | Vòm điêu khắc | Pro | original procedural |
| `abstract.offset-checks` | Offset checks | Ô vuông so le | Pro | original procedural |

## Renderer and cropping

Import `package:handy_boards/covers/cover_art.dart` and give `CoverArt(id)` a bounded box.
The widget fills it, clips overflow, and isolates its paint in a RepaintBoundary. A single
CustomPainter dispatches to sixty different compositions in ten family files.
Its shouldRepaint returns true only when the ID changes; normal size changes still repaint
through Flutter's layout/paint pipeline.

The ground fills the entire box. Foreground compositions are centered at logical (300, 200),
with scale `min(width / 370, height / 240)`. This preserves recognizable objects inside the
central safe frame from 5:1 strips through 1:1 tiles to 3:4 thumbnails. Full-bleed landscape
bands and decorative curves are clipped; their edge details are expendable. Repeating
textiles, tiles and checks visit the visible logical bounds with an overscan tile, so their
patterns continue across a wide or tall box without missing edge strips.

Each composition uses flat opaque grounds that are neither pure white nor pure black.
The art stays the same in light and dark themes. CoverDef.dark describes the artwork's
overall dark ground; the quilt pattern is marked light because its visible pieces dominate.
CoverArt exposes the EN/VI accessible name using the ambient locale and contains no baked-in
letters, numbers, logos or emoji. Unknown, empty and null IDs show a neutral sage still life.
coverTone returns a representative dominant colour; for the garden tile and quilt patterns
it reflects the visible pattern rather than the underlying ground.

All geometry is deterministic. No randomness, shaders, animation, network access, decoding,
per-frame timers or image caches are involved. One Paint is reused within each paint pass;
tile loops only visit visible tiles and scene details use small bounded loops.

## Raster assets and size

| Item | Count | Bundle asset bytes |
| --- | ---: | ---: |
| Raster cover files | 0 | 0 |
| New fonts or other media | 0 | 0 |
| **Total new media payload** | **0** | **0** |

There are no raster files to list, compress or declare. No cover asset entry was needed in
pubspec.yaml. Review PNGs live only in the requested temporary directory and are not bundled.

Measured UTF-8 source sizes: renderer and drawing files **47,066 bytes**; engine cover catalog
**12,219 bytes**; preset data **44,509 bytes**; combined **103,794 bytes**.
These are source sizes, not a measured release APK/AOT or Web JavaScript size delta.
A release binary size comparison and device memory profile were not run.

## Templates

Exactly ten presets are exported in the requested order. The first five are Free and the
last five are Pro. Blank has no categories or cards. Each other preset has four unique
category hue indices, ten cards distributed across every column, five checklists, partial
checklist progress, matching covers, and relative due dates. Total: **90 cards** and
**45 checklists**. Every moodboard card has a cover. Free templates reference only Free covers.

| ID | Name EN / VI | Access | Cards | Checklists | Card covers | Due dates |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `blank` | Blank Kanban / Bảng trống | Free | 0 | 0 | 0 | 0 |
| `study` | Semester 1 / Học kỳ 1 | Free | 10 | 5 | 5 | 3 |
| `personal` | Personal tasks / Việc cá nhân | Free | 10 | 5 | 5 | 3 |
| `shopping` | Wishlist & shopping / Danh sách mua sắm | Free | 10 | 5 | 6 | 3 |
| `project` | Project Kanban / Theo dõi dự án | Free | 10 | 5 | 5 | 3 |
| `content` | Content production / Sản xuất nội dung | Pro | 10 | 5 | 8 | 3 |
| `goals` | Goal roadmap / Lộ trình mục tiêu | Pro | 10 | 5 | 6 | 3 |
| `event` | Event planning / Chuẩn bị sự kiện | Pro | 10 | 5 | 7 | 3 |
| `moodboard` | Creative moodboard / Bảng cảm hứng | Pro | 10 | 5 | 10 | 3 |
| `renovation` | Home renovation / Sửa sang nhà cửa | Pro | 10 | 5 | 8 | 3 |

Data lives entirely in `packages/handy_boards_engine/lib/src/presets.dart`.
It does not create boards, schedule reminders, write storage or gate entitlements.
The consuming application assigns fresh IDs and resolves dueInDays against the creation day.
The shopping preset uses ordinary cards and checklists.

## Contact sheets and visual review

Saved at:

```text
C:\Users\Winka\AppData\Local\Temp\claude\da01c89f6f8df767\8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a\scratchpad\covers
```

Every sheet shows all six covers at **3:1, 1:1, 5:1 and 3:4**, with stable IDs,
Free/Pro status, and EN/VI names. Labels use the app's actual Plus Jakarta Sans font files.

| Family sheet | PNG bytes |
| --- | ---: |
| [study.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/study.png) | 225,550 |
| [work.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/work.png) | 176,779 |
| [goals.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/goals.png) | 175,588 |
| [shopping.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/shopping.png) | 184,031 |
| [home.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/home.png) | 245,329 |
| [creative.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/creative.png) | 185,376 |
| [travel.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/travel.png) | 161,598 |
| [events.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/events.png) | 199,838 |
| [wellness.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/wellness.png) | 198,945 |
| [abstract.png](C:/Users/Winka/AppData/Local/Temp/claude/da01c89f6f8df767/8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a/scratchpad/covers/abstract.png) | 181,296 |
| **Total review-only PNGs** | **1,934,330** |

All ten sheets were opened and visually inspected. A second complete render and inspection
followed fixes to pattern coverage at 5:1, the mountain-pass silhouette, the scale of
foreground objects, dark stationery/jar contrast, and the stepping-stone sprig placement.
A final study-sheet inspection confirmed additional space around the geometry-set pencil.

The set retains a consistent palette and drawing language while changing subjects and
compositions. No sheet has an overflow or missing-art error. These are Flutter host-rendered
review images, not device screenshots. The design skills were applied as a component review
against the existing Boards direction; no app screen or navigation was rebuilt here.

To regenerate from `apps/handy_boards` in PowerShell:

```powershell
$env:SHOTS_DIR = 'C:\Users\Winka\AppData\Local\Temp\claude\da01c89f6f8df767\8a28c3e5-409a-4d30-9828-dcdfdf7bdd5a\scratchpad\covers'
flutter test --no-pub tool/covers_test.dart
```

Without SHOTS_DIR the gallery tests skip and write no files.

## Verification

Final checks ran successfully on the supplied Flutter/Dart SDK:

| Working directory | Command | Result |
| --- | --- | --- |
| packages/handy_boards_engine | `flutter test --no-pub test/covers_test.dart test/presets_test.dart` | PASS: 22 tests |
| apps/handy_boards | `flutter test --no-pub test/cover_art_test.dart` | PASS: 4 tests |
| apps/handy_boards | `flutter test --no-pub tool/covers_test.dart` with SHOTS_DIR | PASS: 10 contact sheets |
| packages/handy_boards_engine | `dart analyze lib/src/covers.dart lib/src/presets.dart test/covers_test.dart test/presets_test.dart` | PASS: no issues |
| apps/handy_boards | `dart analyze lib/covers test/cover_art_test.dart tool/covers_test.dart` | PASS: no issues |

The rendering test exercises all 60 IDs at 300×100, 120×120, 500×100 and 120×160
in both light and dark themes (**480 render configurations**), validates fallback and
Vietnamese semantics, and checks all declared raster entries (zero in this release).
Engine tests validate IDs, family/free counts, bilingual content, ordering, references,
indices, hue uniqueness, checklist progress and content breadth.

All added Dart files were formatted. Earlier failures in the new constant-palette constructor,
gallery height and semantics harness were corrected before these passing final runs.
No unrelated Boards implementation files were repaired or replaced. The shared engine library
received only the two requested part directives from this task; concurrent changes were preserved.

