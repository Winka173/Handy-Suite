# Handy Boards remaining implementation — audit and migration plan

Scope authorized: every uncoded/incomplete item in the preceding review, including
Trello subset, nonworking days and native widgets/shortcuts. No cloud/account/paid
service; preserve app data and real monetization gates.

Reuse: canonical task/grade/class models, grade feasibility/work-session reports,
IANA/DST guards, timeline, portable guards, shared files, SQLite CAS/IndexedDB,
Android widget adapter and share App Group. No alternate exam/task databases.

Batches: (1) reports/calendar/Trello; (2) indexed paging and memory reduction;
(3) cancellable streaming exports; (4) native widget/quick actions; (5) EN/VI,
keyboard/semantics, tests and final build sweep. Native SQL changes are additive,
transactional and tested from v1. Backup extensions are versioned and backwards
readable. Failure never resets data. Physical/iOS/store checks stay separate.

Design contract: retain editorial-greeting seed 1051914986/category identity.
Reports answer which subject needs attention and open existing records. Calendar
shows schedulable days; import previews what will be added; export shows progress
and cancel; widget shows upcoming work. No invented predictions. Empty/malformed/
permission/cancel/revision-conflict states preserve data. Responsive 320–1440,
full-width large-text controls, labelled report rows, no school-only core UI.

Status IN_PROGRESS. Feature matrix and actual QA evidence remain authoritative.

Implemented batches: Study report/CSV, board/resource working calendars, local
Trello subset, versioned lazy SQLite/asset snapshots, IndexedDB file separation,
indexed paged List/Table/search, native cancellable streaming ZIP/PDF and staged
large ZIP restore, async bounded Web export, Android widget/launcher actions,
iOS WidgetKit target/quick actions, owned EN/VI error catalog. Automated tests
include failure/rollback/cancel and round trips. Final platform sweep is underway;
physical/iOS/provider/store certification remains explicitly unverified.
