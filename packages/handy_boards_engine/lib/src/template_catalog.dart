part of '../handy_boards_engine.dart';

// The curated templates: 30 (14 Free, 16 Pro) plus the blank board, which
// has its own short path (see [blankPlan]). Each one only shapes a new
// board; see templates.dart for the rules every entry follows.

// ─── Shared pieces ───────────────────────────────────────────────────────

const _week = SetupOption(
  'week',
  L10n('A week at a time', 'Theo tuần'),
  time: TimePreset('week'),
);
const _month = SetupOption(
  'month',
  L10n('A month at a time', 'Theo tháng'),
  time: TimePreset('month'),
);

const _timeHelp = L10n(
  'How much the Time view shows when you open it. Columns stay your '
      'progress; this only lays cards out by their dates.',
  'Thời gian mở ra xem bao xa. Cột vẫn là tiến độ; phần này chỉ xếp thẻ '
      'theo ngày hạn.',
);

/// The time-view question, starting on a week or on a month.
const _timeWeek = SetupField(
  'range',
  FieldKind.select,
  FieldRole.timeRange,
  label: L10n('Time view', 'Chế độ Thời gian'),
  help: _timeHelp,
  options: [_week, _month],
  optionDefault: 'week',
);
const _timeMonth = SetupField(
  'range',
  FieldKind.select,
  FieldRole.timeRange,
  label: L10n('Time view', 'Chế độ Thời gian'),
  help: _timeHelp,
  options: [_week, _month],
  optionDefault: 'month',
);

// ─── A. Study & learning ─────────────────────────────────────────────────

const _semester = BoardTemplate(
  id: 'semester',
  pro: false,
  group: TemplateGroup.study,
  featured: 1,
  name: L10n('Semester Planner', 'Kế hoạch học kỳ'),
  goal: L10n(
    'Every subject of the term on one board.',
    'Mọi môn của học kỳ trên một bảng.',
  ),
  example: L10n(
    'Labs, assignments and revision, by subject.',
    'Bài lab, bài tập, ôn tập, chia theo môn.',
  ),
  tags: ['study', 'school', 'university', 'học', 'môn', 'học kỳ', 'sinh viên'],
  cover: 'study.notebook-grid',
  columns: [
    TemplateColumn(L10n('Not started', 'Chưa bắt đầu')),
    TemplateColumn(L10n('In progress', 'Đang làm')),
    TemplateColumn(L10n('Completed', 'Hoàn thành'), done: true),
  ],
  time: TimePreset('week', pinned: true),
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Board name', 'Tên bảng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New semester', 'Học kỳ mới'),
    ),
    SetupField(
      'subjects',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Subjects', 'Các môn học'),
      help: L10n(
        'Each subject becomes a coloured category, so a card keeps its '
            'subject in every column. Change them to your own.',
        'Mỗi môn thành một nhóm có màu; thẻ giữ môn của nó ở mọi cột. Sửa '
            'thành các môn của bạn.',
      ),
      placeholder: L10n('Add a subject', 'Thêm môn'),
      chipsDefault: [
        L10n('Web Development', 'Lập trình Web'),
        L10n('Databases', 'Cơ sở dữ liệu'),
        L10n('English', 'Tiếng Anh'),
        L10n('Advanced Maths', 'Toán cao cấp'),
      ],
    ),
    SetupField(
      'end',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Semester ends', 'Kết thúc học kỳ'),
      help: L10n(
        'Shown as a key date on the board, with the days left.',
        'Hiện thành ngày quan trọng trên bảng, kèm số ngày '
            'còn lại.',
      ),
    ),
    _timeWeek,
  ],
  samples: [
    SampleCard(
      L10n('Lab 1: set up the project', 'Lab 1: dựng khung dự án'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Install the tools', 'Cài công cụ'),
        L10n('Run the starter code', 'Chạy code mẫu'),
        L10n('Hand it in', 'Nộp bài'),
      ],
      done: 1,
      cover: 'study.pencil-case',
      dueOffset: 3,
    ),
    SampleCard(
      L10n('Draw the ERD for the topic', 'Vẽ ERD cho đề tài'),
      column: 0,
      category: 1,
      dueOffset: 6,
    ),
    SampleCard(
      L10n('Essay, 250 words', 'Bài luận 250 từ'),
      column: 0,
      category: 2,
      subtasks: [
        L10n('Outline', 'Dàn ý'),
        L10n('First draft', 'Bản nháp'),
        L10n('Proofread', 'Soát lỗi'),
      ],
    ),
    SampleCard(L10n('Revise chapter 2', 'Ôn chương 2'), column: 2, category: 3),
  ],
);

const _groupAssignment = BoardTemplate(
  id: 'group-assignment',
  pro: false,
  group: TemplateGroup.study,
  featured: 2,
  name: L10n('Group Assignment', 'Bài tập nhóm'),
  goal: L10n(
    'One assignment, from research to the final check.',
    'Một bài tập, từ tìm hiểu tới kiểm tra lần cuối.',
  ),
  example: L10n(
    'Research notes, a draft and presentation slides.',
    'Ghi chép tìm hiểu, bản nháp và trang trình bày.',
  ),
  tags: ['assignment', 'group', 'research', 'bài tập', 'nhóm', 'nghiên cứu'],
  cover: 'study.open-book',
  look: 'paper',
  hues: [1, 4, 2, 0],
  time: TimePreset('week', pinned: true),
  columns: [
    TemplateColumn(L10n('To Do', 'Cần làm')),
    TemplateColumn(L10n('Doing', 'Đang làm')),
    TemplateColumn(L10n('Review', 'Cần xem lại'), onlyWith: 'review'),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Assignment name', 'Tên bài tập'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New assignment', 'Bài tập mới'),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Work areas', 'Các mảng việc'),
      help: L10n(
        'Each area becomes a category on one device; there is no shared '
            'real-time team board.',
        'Mỗi mảng thành một nhóm trên một thiết bị; bảng không có chế độ cộng '
            'tác nhóm theo thời gian thực.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Research', 'Nghiên cứu'),
        L10n('Design', 'Thiết kế'),
        L10n('Implementation', 'Thực hiện'),
        L10n('Presentation', 'Trình bày'),
      ],
    ),
    SetupField(
      'submission',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Submission date', 'Ngày nộp bài'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'review',
      FieldKind.toggle,
      FieldRole.optionalColumns,
      label: L10n('Review step', 'Bước xem lại'),
      help: L10n(
        'Keeps or removes the Review column.',
        'Giữ hoặc bỏ cột Cần xem lại.',
      ),
      toggleDefault: true,
    ),
  ],
  samples: [
    SampleCard(
      L10n('Collect notes for the topic', 'Thu thập ghi chép cho đề tài'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Find two sources', 'Tìm hai nguồn tài liệu'),
        L10n('Note the main points', 'Ghi lại ý chính'),
        L10n('Keep the source links', 'Lưu đường dẫn nguồn'),
      ],
      done: 1,
      cover: 'study.pencil-case',
    ),
    SampleCard(
      L10n('Sketch the page layout', 'Phác thảo bố cục trang'),
      column: 0,
      category: 1,
    ),
    SampleCard(
      L10n('Rehearse the presentation', 'Tập trình bày'),
      column: 0,
      category: 3,
      subtasks: [
        L10n('Arrange the slides', 'Sắp xếp các trang trình bày'),
        L10n('Read through once', 'Đọc thử một lượt'),
      ],
      done: 0,
      dueOffset: -2,
      anchor: 'submission',
    ),
  ],
);

const _examRevision = BoardTemplate(
  id: 'exam-revision',
  pro: false,
  group: TemplateGroup.study,
  name: L10n('Exam Revision', 'Ôn thi'),
  goal: L10n(
    'Work through topics until they feel familiar.',
    'Ôn từng chủ đề cho tới khi nắm vững.',
  ),
  example: L10n(
    'A chapter summary, practice questions and a timed exercise.',
    'Tóm tắt chương, câu hỏi luyện tập và bài làm có bấm giờ.',
  ),
  tags: ['exam', 'revision', 'practice', 'ôn thi', 'ôn tập', 'luyện tập'],
  cover: 'study.pencil-case',
  look: 'mist',
  hues: [2, 0, 4, 1],
  time: TimePreset('week', count: 2, pinned: true),
  columns: [
    TemplateColumn(L10n('To Review', 'Cần ôn')),
    TemplateColumn(L10n('Reviewing', 'Đang ôn')),
    TemplateColumn(L10n('Practiced', 'Đã luyện tập')),
    TemplateColumn(L10n('Ready', 'Sẵn sàng'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Revision plan name', 'Tên kế hoạch ôn tập'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Exam revision', 'Ôn thi'),
    ),
    SetupField(
      'subjects',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Subjects or topics', 'Môn học hoặc chủ đề'),
      help: L10n(
        'Each topic becomes a category for cards that represent units to '
            'review.',
        'Mỗi chủ đề thành một nhóm cho các thẻ ghi từng phần cần ôn.',
      ),
      placeholder: L10n('Add a topic', 'Thêm chủ đề'),
      chipsDefault: [
        L10n('Algebra', 'Đại số'),
        L10n('Geometry', 'Hình học'),
        L10n('Reading', 'Đọc hiểu'),
      ],
    ),
    SetupField(
      'exam',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Exam date', 'Ngày thi'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    _timeWeek,
  ],
  samples: [
    SampleCard(
      L10n('Summarize linear equations', 'Tóm tắt phương trình bậc nhất'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Write the key rules', 'Ghi các quy tắc chính'),
        L10n('Work through two examples', 'Làm thử hai ví dụ'),
        L10n('Note common mistakes', 'Ghi các lỗi thường gặp'),
      ],
      done: 1,
      cover: 'study.notebook-grid',
    ),
    SampleCard(
      L10n('Practice area problems', 'Luyện bài tập tính diện tích'),
      column: 0,
      category: 1,
      dueOffset: -3,
      anchor: 'exam',
    ),
    SampleCard(
      L10n('Review one short passage', 'Ôn một đoạn đọc ngắn'),
      column: 2,
      category: 2,
    ),
  ],
);

const _course = BoardTemplate(
  id: 'course',
  pro: true,
  group: TemplateGroup.study,
  name: L10n('Personal Course', 'Khóa học cá nhân'),
  goal: L10n(
    'A place for each lesson and its practice.',
    'Một nơi cho từng bài học và phần thực hành.',
  ),
  example: L10n(
    'Read a module, try an exercise, finish a small project.',
    'Đọc một học phần, làm bài tập, hoàn thành dự án nhỏ.',
  ),
  tags: ['course', 'learning', 'module', 'khóa học', 'tự học', 'học phần'],
  cover: 'study.library-steps',
  look: 'linen',
  hues: [4, 1, 0, 3],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Upcoming', 'Sắp học')),
    TemplateColumn(L10n('Learning', 'Đang học')),
    TemplateColumn(L10n('Practicing', 'Đang thực hành')),
    TemplateColumn(L10n('Finished', 'Hoàn thành'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Course name', 'Tên khóa học'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('My course', 'Khóa học của tôi'),
    ),
    SetupField(
      'modules',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Chapters or modules', 'Chương hoặc học phần'),
      help: L10n(
        'Modules become categories and progress comes from finished cards; '
            'this is not an LMS.',
        'Học phần thành các nhóm và tiến độ tính từ thẻ đã hoàn thành; đây '
            'không phải hệ thống quản lý học tập.',
      ),
      placeholder: L10n('Add a module', 'Thêm học phần'),
      chipsDefault: [
        L10n('Foundations', 'Nền tảng'),
        L10n('Practice', 'Thực hành'),
        L10n('Project', 'Dự án'),
      ],
    ),
    SetupField(
      'finish',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Target completion date', 'Ngày dự kiến hoàn thành'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
  ],
  samples: [
    SampleCard(
      L10n('Read the introductory lesson', 'Đọc bài học mở đầu'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Read the notes', 'Đọc ghi chú'),
        L10n('Write a short summary', 'Viết tóm tắt ngắn'),
      ],
      done: 1,
      cover: 'study.orbital-notes',
    ),
    SampleCard(
      L10n('Try the first exercise', 'Làm thử bài tập đầu tiên'),
      column: 2,
      category: 1,
    ),
    SampleCard(
      L10n('Build a small example project', 'Làm dự án mẫu nhỏ'),
      column: 0,
      category: 2,
      dueOffset: -2,
      anchor: 'finish',
    ),
  ],
);

const _thesis = BoardTemplate(
  id: 'thesis',
  pro: true,
  group: TemplateGroup.study,
  name: L10n('Thesis / Capstone', 'Luận văn / Đồ án'),
  goal: L10n(
    'Move each part from a first draft to approval.',
    'Đưa từng phần từ bản nháp tới được duyệt.',
  ),
  example: L10n(
    'A reading summary, a methods draft and a final check.',
    'Tóm tắt tài liệu, bản nháp phương pháp và lượt kiểm tra cuối.',
  ),
  tags: ['thesis', 'capstone', 'research', 'luận văn', 'đồ án', 'nghiên cứu'],
  cover: 'study.orbital-notes',
  look: 'blueprint',
  hues: [0, 4, 1, 5],
  time: TimePreset('week', count: 2, pinned: true),
  columns: [
    TemplateColumn(L10n('Backlog', 'Việc chờ')),
    TemplateColumn(L10n('Drafting', 'Đang soạn')),
    TemplateColumn(L10n('Review', 'Cần xem lại'), onlyWith: 'review'),
    TemplateColumn(L10n('Approved', 'Đã duyệt'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Thesis or capstone title', 'Tên luận văn hoặc đồ án'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('My capstone', 'Đồ án của tôi'),
    ),
    SetupField(
      'workstreams',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Sections or workstreams', 'Các phần hoặc mảng việc'),
      help: L10n(
        'Each workstream becomes a category, while columns show progress.',
        'Mỗi mảng việc thành một nhóm, còn cột thể hiện tiến độ.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Literature', 'Tài liệu'),
        L10n('Methods', 'Phương pháp'),
        L10n('Results', 'Kết quả'),
        L10n('Discussion', 'Thảo luận'),
      ],
    ),
    SetupField(
      'due',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Due date', 'Hạn nộp'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'review',
      FieldKind.toggle,
      FieldRole.optionalColumns,
      label: L10n('Review step', 'Bước xem lại'),
      help: L10n(
        'Keeps or removes the Review column.',
        'Giữ hoặc bỏ cột Cần xem lại.',
      ),
      toggleDefault: true,
    ),
  ],
  samples: [
    SampleCard(
      L10n(
        'Summarize three relevant sources',
        'Tóm tắt ba nguồn tài liệu liên quan',
      ),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Collect the sources', 'Tập hợp tài liệu'),
        L10n('Compare the main findings', 'So sánh các kết quả chính'),
        L10n('Record citations', 'Ghi thông tin trích dẫn'),
      ],
      done: 1,
      cover: 'study.library-steps',
    ),
    SampleCard(
      L10n('Draft the methods section', 'Soạn phần phương pháp'),
      column: 0,
      category: 1,
    ),
    SampleCard(
      L10n('Check figures and captions', 'Kiểm tra hình và chú thích'),
      column: 0,
      category: 2,
      dueOffset: -5,
      anchor: 'due',
    ),
  ],
);

const _language = BoardTemplate(
  id: 'language',
  pro: true,
  group: TemplateGroup.study,
  name: L10n('Language Learning', 'Học ngoại ngữ'),
  goal: L10n(
    'Keep reading, listening, speaking and writing moving.',
    'Duy trì việc đọc, nghe, nói và viết.',
  ),
  example: L10n(
    'Read a short text, repeat a dialogue, write a paragraph.',
    'Đọc đoạn văn ngắn, tập lại hội thoại, viết một đoạn văn.',
  ),
  tags: ['language', 'reading', 'speaking', 'ngoại ngữ', 'đọc', 'nói'],
  cover: 'study.geometry-set',
  look: 'meadow',
  hues: [3, 2, 4, 6],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Planned', 'Dự định')),
    TemplateColumn(L10n('Practising', 'Đang luyện')),
    TemplateColumn(L10n('Needs review', 'Cần ôn lại')),
    TemplateColumn(L10n('Completed', 'Hoàn thành'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Language studied', 'Ngôn ngữ đang học'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Learning Japanese', 'Học tiếng Nhật'),
    ),
    SetupField(
      'skills',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Skills', 'Các kỹ năng'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a skill', 'Thêm kỹ năng'),
      chipsDefault: [
        L10n('Reading', 'Đọc'),
        L10n('Listening', 'Nghe'),
        L10n('Speaking', 'Nói'),
        L10n('Writing', 'Viết'),
      ],
    ),
    _timeWeek,
  ],
  samples: [
    SampleCard(
      L10n('Read a short everyday story', 'Đọc truyện ngắn về đời sống'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Read once for meaning', 'Đọc một lượt để hiểu ý'),
        L10n('Note three useful phrases', 'Ghi ba cụm từ hữu ích'),
        L10n('Read aloud', 'Đọc thành tiếng'),
      ],
      done: 1,
      cover: 'study.open-book',
      dueOffset: 2,
    ),
    SampleCard(
      L10n('Listen to a short dialogue', 'Nghe một đoạn hội thoại ngắn'),
      column: 2,
      category: 1,
    ),
    SampleCard(
      L10n('Write about a familiar place', 'Viết về một nơi quen thuộc'),
      column: 0,
      category: 3,
      dueOffset: 4,
    ),
  ],
);

// ─── B. Work & projects ──────────────────────────────────────────────────

const _project = BoardTemplate(
  id: 'project',
  pro: false,
  group: TemplateGroup.work,
  featured: 3,
  name: L10n('Project Kanban', 'Dự án Kanban'),
  goal: L10n(
    'A project from backlog to done, by work area.',
    'Một dự án từ việc chờ tới xong, theo mảng việc.',
  ),
  example: L10n(
    'Features, content and testing for one launch.',
    'Tính năng, nội dung, kiểm thử cho một lần ra mắt.',
  ),
  tags: ['project', 'work', 'team', 'dự án', 'công việc', 'kanban'],
  cover: 'work.sticky-plan',
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Backlog', 'Việc chờ')),
    TemplateColumn(L10n('In progress', 'Đang làm')),
    TemplateColumn(L10n('Review', 'Cần xem lại'), onlyWith: 'review'),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Project name', 'Tên dự án'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New project', 'Dự án mới'),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Work areas', 'Các mảng việc'),
      help: L10n(
        'Each area becomes a category: what a card is about, not how far '
            'along it is.',
        'Mỗi mảng thành một nhóm: thẻ nói về việc gì, không phải đang tới '
            'đâu.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Interface', 'Giao diện'),
        L10n('Features', 'Tính năng'),
        L10n('Content', 'Nội dung'),
        L10n('Testing', 'Kiểm thử'),
      ],
    ),
    SetupField(
      'review',
      FieldKind.toggle,
      FieldRole.optionalColumns,
      label: L10n('Add a Review column', 'Thêm cột Cần xem lại'),
      help: L10n(
        'For work someone checks before it is done.',
        'Cho việc cần được xem lại trước khi xong.',
      ),
    ),
  ],
  samples: [
    SampleCard(
      L10n('Sketch the main screen', 'Phác thảo màn hình chính'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Three layouts', 'Ba bố cục'),
        L10n('Pick one', 'Chọn một'),
      ],
      done: 1,
      cover: 'work.desk-light',
      dueOffset: 2,
    ),
    SampleCard(
      L10n('Write the sign-up flow', 'Làm luồng đăng ký'),
      column: 0,
      category: 1,
      dueOffset: 5,
    ),
    SampleCard(
      L10n('Check on a small phone', 'Kiểm tra trên điện thoại nhỏ'),
      column: 0,
      category: 3,
    ),
  ],
);

const _weekly = BoardTemplate(
  id: 'weekly',
  pro: false,
  group: TemplateGroup.work,
  featured: 4,
  name: L10n('Weekly Work Plan', 'Kế hoạch làm việc tuần'),
  goal: L10n(
    'Give this week’s work a clear next step.',
    'Xác định bước tiếp theo cho công việc tuần này.',
  ),
  example: L10n(
    'Prepare a draft, check a change, close a small task.',
    'Soạn bản nháp, kiểm tra thay đổi, hoàn tất việc nhỏ.',
  ),
  tags: ['weekly', 'work', 'plan', 'tuần', 'công việc', 'kế hoạch'],
  cover: 'work.folder-stack',
  look: 'sage',
  hues: [3, 0, 2, 4],
  time: TimePreset('week', pinned: true),
  columns: [
    TemplateColumn(L10n('Planned', 'Dự định')),
    TemplateColumn(L10n('Doing', 'Đang làm')),
    TemplateColumn(L10n('Completed', 'Hoàn thành'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Board name', 'Tên bảng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('This week’s work', 'Công việc tuần này'),
    ),
    SetupField(
      'start',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Week starts', 'Tuần bắt đầu'),
      help: L10n(
        'Adds the week’s start as a key date; tasks keep their status '
            'independent of due dates.',
        'Thêm ngày bắt đầu tuần làm ngày quan trọng; trạng thái công việc độc '
            'lập với ngày hạn.',
      ),
      dateDefault: 'weekStart',
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Work areas', 'Các mảng việc'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Planning', 'Lập kế hoạch'),
        L10n('Delivery', 'Thực hiện'),
        L10n('Admin', 'Hành chính'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n(
        'Outline the week’s priorities',
        'Phác thảo việc ưu tiên trong tuần',
      ),
      column: 1,
      category: 0,
      subtasks: [
        L10n('List the open tasks', 'Liệt kê việc còn mở'),
        L10n('Choose three priorities', 'Chọn ba việc ưu tiên'),
      ],
      done: 1,
      cover: 'work.sticky-plan',
      dueOffset: 0,
      anchor: 'start',
    ),
    SampleCard(
      L10n('Prepare a first draft', 'Chuẩn bị bản nháp đầu tiên'),
      column: 0,
      category: 1,
      dueOffset: 2,
      anchor: 'start',
    ),
    SampleCard(
      L10n('Sort the reference files', 'Sắp xếp tệp tham khảo'),
      column: 2,
      category: 2,
    ),
  ],
);

const _sprint = BoardTemplate(
  id: 'sprint',
  pro: true,
  group: TemplateGroup.work,
  name: L10n('Development Sprint', 'Đợt phát triển'),
  goal: L10n(
    'Take a small batch of work through development and testing.',
    'Đưa một nhóm việc qua bước phát triển và kiểm thử.',
  ),
  example: L10n(
    'A screen, a validation rule and a test pass.',
    'Một màn hình, quy tắc kiểm tra dữ liệu và lượt kiểm thử.',
  ),
  tags: [
    'sprint',
    'development',
    'testing',
    'phát triển',
    'kiểm thử',
    'đợt làm việc',
  ],
  cover: 'work.architect-desk',
  look: 'blueprint',
  hues: [0, 1, 5, 3],
  time: TimePreset('week', count: 2, pinned: true),
  columns: [
    TemplateColumn(L10n('Backlog', 'Việc chờ')),
    TemplateColumn(L10n('Developing', 'Đang phát triển')),
    TemplateColumn(L10n('Testing', 'Đang kiểm thử')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Sprint name', 'Tên đợt phát triển'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New sprint', 'Đợt phát triển mới'),
    ),
    SetupField(
      'sprint',
      FieldKind.dateRange,
      FieldRole.milestone,
      label: L10n('Sprint starts', 'Đợt phát triển bắt đầu'),
      help: L10n(
        'Adds the sprint’s start and end as key dates on the board.',
        'Không bắt buộc; thêm ngày bắt đầu và kết thúc đợt phát triển làm ngày '
            'quan trọng trên bảng.',
      ),
      endLabel: L10n('Sprint ends', 'Đợt phát triển kết thúc'),
    ),
    SetupField(
      'workstreams',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Workstreams', 'Các mảng việc'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Interface', 'Giao diện'),
        L10n('Logic', 'Xử lý'),
        L10n('Testing', 'Kiểm thử'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Build the empty state', 'Làm giao diện khi chưa có dữ liệu'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Sketch the layout', 'Phác thảo bố cục'),
        L10n('Add the text', 'Thêm nội dung chữ'),
        L10n('Check narrow screens', 'Kiểm tra màn hình hẹp'),
      ],
      done: 1,
      cover: 'work.paper-clips',
    ),
    SampleCard(
      L10n('Validate a required field', 'Kiểm tra trường bắt buộc'),
      column: 0,
      category: 1,
    ),
    SampleCard(
      L10n(
        'Run the acceptance checklist',
        'Thực hiện danh sách kiểm tra nghiệm thu',
      ),
      column: 2,
      category: 2,
      dueOffset: -1,
      anchor: 'sprint.end',
    ),
  ],
);

const _ideas = BoardTemplate(
  id: 'ideas',
  pro: false,
  group: TemplateGroup.work,
  name: L10n('Idea Pipeline', 'Luồng ý tưởng'),
  goal: L10n(
    'Keep an idea’s next step beside the idea itself.',
    'Giữ bước tiếp theo ngay cạnh mỗi ý tưởng.',
  ),
  example: L10n(
    'A rough note, a small experiment and an idea to try.',
    'Ghi chú ban đầu, thử nghiệm nhỏ và ý tưởng để thực hiện.',
  ),
  tags: ['ideas', 'brainstorm', 'explore', 'ý tưởng', 'sáng kiến', 'khám phá'],
  cover: 'abstract.split-circle',
  look: 'clay',
  hues: [4, 6, 1, 2],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Inbox', 'Mới ghi')),
    TemplateColumn(L10n('Exploring', 'Đang tìm hiểu')),
    TemplateColumn(L10n('Selected', 'Đã chọn')),
    TemplateColumn(L10n('Implemented', 'Đã thực hiện'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Board name', 'Tên bảng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Ideas to explore', 'Ý tưởng để tìm hiểu'),
    ),
    SetupField(
      'topics',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Idea topics', 'Chủ đề ý tưởng'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a topic', 'Thêm chủ đề'),
      chipsDefault: [
        L10n('Product', 'Sản phẩm'),
        L10n('Process', 'Quy trình'),
        L10n('Experiments', 'Thử nghiệm'),
      ],
    ),
    SetupField(
      'style',
      FieldKind.select,
      FieldRole.presentation,
      label: L10n('Card style', 'Kiểu thẻ'),
      help: L10n(
        'Changes how much of each card and its cover is shown.',
        'Đổi lượng nội dung và ảnh bìa hiển thị trên mỗi thẻ.',
      ),
      options: [
        SetupOption('compact', L10n('Compact', 'Gọn'), presentation: 'compact'),
        SetupOption(
          'detailed',
          L10n('Cover-forward', 'Nổi bật ảnh bìa'),
          presentation: 'detailed',
        ),
      ],
      optionDefault: 'compact',
    ),
  ],
  samples: [
    SampleCard(
      L10n('Try a simpler welcome screen', 'Thử màn hình chào đơn giản hơn'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Sketch two approaches', 'Phác thảo hai cách'),
        L10n(
          'Note what each makes easier',
          'Ghi điểm thuận tiện của từng cách',
        ),
      ],
      done: 1,
      cover: 'creative.paper-collage',
    ),
    SampleCard(
      L10n('Collect steps worth shortening', 'Ghi lại các bước có thể rút gọn'),
      column: 0,
      category: 1,
      cover: 'abstract.balanced-forms',
    ),
    SampleCard(
      L10n('Prototype a small shortcut', 'Làm mẫu thử cho một thao tác nhanh'),
      column: 2,
      category: 2,
      cover: 'goals.stepping-stones',
    ),
  ],
);

const _launch = BoardTemplate(
  id: 'launch',
  pro: true,
  group: TemplateGroup.work,
  name: L10n('Product Launch', 'Ra mắt sản phẩm'),
  goal: L10n(
    'Bring the product and its launch materials to ready.',
    'Chuẩn bị sản phẩm và tài liệu ra mắt.',
  ),
  example: L10n(
    'A product check, a short description and launch artwork.',
    'Kiểm tra sản phẩm, mô tả ngắn và hình ảnh ra mắt.',
  ),
  tags: ['launch', 'product', 'release', 'ra mắt', 'sản phẩm', 'phát hành'],
  cover: 'events.stage-curtain',
  look: 'ink',
  hues: [5, 4, 0, 2],
  time: TimePreset('month', pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('Planning', 'Lên kế hoạch')),
    TemplateColumn(L10n('Producing', 'Đang thực hiện')),
    TemplateColumn(L10n('Review', 'Cần xem lại')),
    TemplateColumn(L10n('Launched', 'Đã ra mắt'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Product name', 'Tên sản phẩm'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New product launch', 'Ra mắt sản phẩm mới'),
    ),
    SetupField(
      'launch',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Launch date', 'Ngày ra mắt'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Areas', 'Các mảng việc'),
      help: L10n(
        'Each area becomes a category for manual launch tasks, without a store '
            'connection.',
        'Mỗi mảng thành một nhóm cho việc ra mắt làm thủ công, không kết nối '
            'với cửa hàng.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Product', 'Sản phẩm'),
        L10n('Marketing', 'Tiếp thị'),
        L10n('Store', 'Cửa hàng'),
        L10n('Quality', 'Chất lượng'),
      ],
    ),
    _timeMonth,
  ],
  samples: [
    SampleCard(
      L10n('Check the first-use flow', 'Kiểm tra luồng sử dụng lần đầu'),
      column: 1,
      category: 3,
      subtasks: [
        L10n('Start with an empty setup', 'Bắt đầu với thiết lập trống'),
        L10n('Try the main action', 'Thử thao tác chính'),
        L10n('Read every message', 'Đọc từng thông báo'),
      ],
      done: 1,
      cover: 'goals.milestone-flags',
    ),
    SampleCard(
      L10n('Draft the product description', 'Soạn mô tả sản phẩm'),
      column: 0,
      category: 2,
      dueOffset: -5,
      anchor: 'launch',
    ),
    SampleCard(
      L10n('Prepare the announcement image', 'Chuẩn bị ảnh thông báo ra mắt'),
      column: 0,
      category: 1,
      cover: 'events.confetti-cutouts',
      dueOffset: -2,
      anchor: 'launch',
    ),
  ],
);

const _meeting = BoardTemplate(
  id: 'meeting',
  pro: true,
  group: TemplateGroup.work,
  name: L10n('Meeting Actions', 'Việc sau cuộc họp'),
  goal: L10n(
    'Turn discussion notes into clear actions.',
    'Chuyển ghi chép thảo luận thành việc cụ thể.',
  ),
  example: L10n(
    'Clarify a question, write a summary, follow up on an action.',
    'Làm rõ câu hỏi, viết tóm tắt, theo dõi một đầu việc.',
  ),
  tags: ['meeting', 'actions', 'follow-up', 'cuộc họp', 'đầu việc', 'theo dõi'],
  cover: 'work.inbox-trays',
  look: 'harbor',
  hues: [0, 3, 1, 4],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Action items', 'Việc cần làm')),
    TemplateColumn(L10n('In progress', 'Đang làm')),
    TemplateColumn(L10n('Follow-up', 'Cần theo dõi')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Meeting title', 'Tên cuộc họp'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Discussion actions', 'Việc sau thảo luận'),
    ),
    SetupField(
      'meeting',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Meeting date', 'Ngày họp'),
      help: L10n(
        'Adds a key date for context, not a deadline for every card.',
        'Không bắt buộc; thêm ngày quan trọng để ghi bối cảnh, không phải hạn '
            'cho mọi thẻ.',
      ),
    ),
    SetupField(
      'groups',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Action groups', 'Nhóm đầu việc'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Decisions', 'Quyết định'),
        L10n('Questions', 'Câu hỏi'),
        L10n('Follow-up', 'Theo dõi'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Write a short decision summary', 'Viết tóm tắt các quyết định'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Review the notes', 'Đọc lại ghi chép'),
        L10n('Separate actions from context', 'Tách đầu việc khỏi bối cảnh'),
      ],
      done: 1,
      cover: 'work.folder-stack',
    ),
    SampleCard(
      L10n('Clarify an open question', 'Làm rõ câu hỏi còn bỏ ngỏ'),
      column: 0,
      category: 1,
    ),
    SampleCard(
      L10n(
        'Check the next step on an action',
        'Kiểm tra bước tiếp theo của một đầu việc',
      ),
      column: 2,
      category: 2,
    ),
  ],
);

// ─── C. Personal & home ──────────────────────────────────────────────────

const _personal = BoardTemplate(
  id: 'personal',
  pro: false,
  group: TemplateGroup.personal,
  featured: 5,
  name: L10n('Personal Tasks', 'Việc cá nhân'),
  goal: L10n(
    'Keep everyday tasks in one place.',
    'Gom việc thường ngày vào một chỗ.',
  ),
  example: L10n(
    'A small repair, a form to sort and something to learn.',
    'Sửa một món đồ, sắp xếp giấy tờ và học điều mới.',
  ),
  tags: ['personal', 'tasks', 'home', 'cá nhân', 'việc cần làm', 'nhà cửa'],
  cover: 'wellness.morning-leaves',
  look: 'sage',
  hues: [3, 2, 0, 4],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('To Do', 'Cần làm')),
    TemplateColumn(L10n('Doing', 'Đang làm')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Board title', 'Tên bảng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('My tasks', 'Việc của tôi'),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Life areas', 'Các mảng cuộc sống'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Home', 'Nhà cửa'),
        L10n('Personal', 'Cá nhân'),
        L10n('Paperwork', 'Giấy tờ'),
        L10n('Learning', 'Học tập'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Tidy the desk drawer', 'Dọn ngăn kéo bàn'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Take everything out', 'Lấy hết đồ ra'),
        L10n('Keep what belongs here', 'Giữ lại đồ cần để ở đây'),
        L10n('Put things back', 'Xếp đồ lại'),
      ],
      done: 1,
      cover: 'home.woven-linen',
    ),
    SampleCard(
      L10n('Sort the loose documents', 'Sắp xếp giấy tờ rời'),
      column: 0,
      category: 2,
    ),
    SampleCard(
      L10n('Try a short drawing lesson', 'Học thử một bài vẽ ngắn'),
      column: 0,
      category: 3,
      cover: 'creative.paint-palette',
    ),
  ],
);

const _shopping = BoardTemplate(
  id: 'shopping',
  pro: false,
  group: TemplateGroup.personal,
  featured: 6,
  name: L10n('Shopping Planner', 'Kế hoạch mua sắm'),
  goal: L10n(
    'From wanting it to having it.',
    'Từ muốn mua tới đã có trong tay.',
  ),
  example: L10n(
    'A new desk lamp, a gift, things for home.',
    'Đèn bàn mới, một món quà, đồ cho nhà.',
  ),
  tags: ['shopping', 'buy', 'gift', 'mua sắm', 'quà', 'đồ dùng'],
  cover: 'shopping.market-tote',
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Want', 'Muốn mua')),
    TemplateColumn(L10n('Comparing', 'Đang so sánh')),
    TemplateColumn(L10n('Ordered', 'Đã đặt')),
    TemplateColumn(L10n('Received', 'Đã nhận'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('List name', 'Tên danh sách'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('To buy', 'Cần mua'),
    ),
    SetupField(
      'groups',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Kinds of things', 'Loại đồ'),
      help: L10n(
        'Each becomes a category. Prices and links go in a card’s notes; '
            'the app never looks up prices or buys anything.',
        'Mỗi loại thành một nhóm. Giá và link ghi trong ghi chú của thẻ; app '
            'không tra giá hay mua hộ.',
      ),
      placeholder: L10n('Add a kind', 'Thêm loại'),
      chipsDefault: [
        L10n('Tech', 'Công nghệ'),
        L10n('Personal', 'Cá nhân'),
        L10n('Home', 'Nhà cửa'),
        L10n('Gifts', 'Quà tặng'),
      ],
    ),
    SetupField(
      'style',
      FieldKind.select,
      FieldRole.columnSet,
      label: L10n('How you shop', 'Bạn hay mua thế nào'),
      help: L10n('Only changes the column names.', 'Chỉ đổi tên các cột.'),
      options: [
        SetupOption(
          'online',
          L10n('Online', 'Mua online'),
          columns: [
            TemplateColumn(L10n('Want', 'Muốn mua')),
            TemplateColumn(L10n('Comparing', 'Đang so sánh')),
            TemplateColumn(L10n('Ordered', 'Đã đặt')),
            TemplateColumn(L10n('Received', 'Đã nhận'), done: true),
          ],
        ),
        SetupOption(
          'store',
          L10n('In a shop', 'Mua tại cửa hàng'),
          columns: [
            TemplateColumn(L10n('Want', 'Muốn mua')),
            TemplateColumn(L10n('Comparing', 'Đang so sánh')),
            TemplateColumn(L10n('Going to buy', 'Sẽ đi mua')),
            TemplateColumn(L10n('Bought', 'Đã mua'), done: true),
          ],
        ),
        SetupOption(
          'mixed',
          L10n('Both', 'Cả hai'),
          columns: [
            TemplateColumn(L10n('Want', 'Muốn mua')),
            TemplateColumn(L10n('Comparing', 'Đang so sánh')),
            TemplateColumn(L10n('Ordered or buying', 'Đã đặt / sẽ mua')),
            TemplateColumn(L10n('Have it', 'Đã có'), done: true),
          ],
        ),
      ],
      optionDefault: 'mixed',
    ),
  ],
  samples: [
    SampleCard(
      L10n('Desk lamp with warm light', 'Đèn bàn ánh sáng ấm'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Compare two models', 'So sánh hai mẫu'),
        L10n('Read the reviews', 'Đọc đánh giá'),
      ],
      done: 1,
      cover: 'shopping.wish-shelf',
    ),
    SampleCard(
      L10n('Birthday gift', 'Quà sinh nhật'),
      column: 0,
      category: 3,
      cover: 'shopping.wrapped-parcel',
      dueOffset: 10,
    ),
    SampleCard(
      L10n('Laundry basket', 'Giỏ đựng đồ giặt'),
      column: 2,
      category: 2,
    ),
  ],
);

const _homeImprovement = BoardTemplate(
  id: 'home-improvement',
  pro: true,
  group: TemplateGroup.personal,
  name: L10n('Home Improvement', 'Cải thiện nhà cửa'),
  goal: L10n(
    'Take a room project from preparation to the last touch.',
    'Đưa việc sửa sang một phòng từ chuẩn bị tới hoàn thiện.',
  ),
  example: L10n(
    'Choose a wall colour, prepare the space, fit a shelf.',
    'Chọn màu tường, chuẩn bị không gian, lắp kệ.',
  ),
  tags: ['home', 'improvement', 'room', 'nhà cửa', 'sửa sang', 'phòng'],
  cover: 'home.courtyard',
  look: 'terracotta',
  hues: [6, 3, 2, 4],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('To Do', 'Cần làm')),
    TemplateColumn(L10n('Preparing', 'Đang chuẩn bị')),
    TemplateColumn(L10n('In Progress', 'Đang thực hiện')),
    TemplateColumn(L10n('Completed', 'Hoàn thành'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Project or room title', 'Tên dự án hoặc phòng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Room refresh', 'Làm mới căn phòng'),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Areas or rooms', 'Khu vực hoặc phòng'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a room', 'Thêm phòng'),
      chipsDefault: [
        L10n('Living room', 'Phòng khách'),
        L10n('Bedroom', 'Phòng ngủ'),
        L10n('Kitchen', 'Bếp'),
      ],
    ),
    SetupField(
      'finish',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Desired completion date', 'Ngày mong muốn hoàn thành'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
  ],
  samples: [
    SampleCard(
      L10n('Choose a wall colour', 'Chọn màu tường'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Collect colour samples', 'Tập hợp mẫu màu'),
        L10n('Check them in daylight', 'Xem mẫu dưới ánh sáng ban ngày'),
        L10n('Pick one shade', 'Chọn một tông màu'),
      ],
      done: 1,
      cover: 'home.reading-corner',
    ),
    SampleCard(
      L10n('Clear space for a shelf', 'Dọn chỗ đặt kệ'),
      column: 0,
      category: 1,
      cover: 'home.arched-window',
    ),
    SampleCard(
      L10n('Fit a small kitchen shelf', 'Lắp kệ nhỏ trong bếp'),
      column: 0,
      category: 2,
      dueOffset: -2,
      anchor: 'finish',
    ),
  ],
);

const _event = BoardTemplate(
  id: 'event',
  pro: true,
  group: TemplateGroup.personal,
  name: L10n('Event Planning', 'Chuẩn bị sự kiện'),
  goal: L10n(
    'Keep the preparations moving towards the event.',
    'Theo dõi việc chuẩn bị cho tới ngày sự kiện.',
  ),
  example: L10n(
    'Arrange the space, choose food and prepare decorations.',
    'Sắp xếp không gian, chọn món ăn và chuẩn bị trang trí.',
  ),
  tags: ['event', 'preparation', 'gathering', 'sự kiện', 'chuẩn bị', 'gặp mặt'],
  cover: 'events.ribbon-invite',
  look: 'blush',
  hues: [4, 6, 3, 1],
  time: TimePreset('week', count: 2, pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('To prepare', 'Cần chuẩn bị')),
    TemplateColumn(L10n('Working on', 'Đang làm')),
    TemplateColumn(L10n('Awaiting confirmation', 'Chờ xác nhận')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Event name', 'Tên sự kiện'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('A small gathering', 'Buổi gặp mặt nhỏ'),
    ),
    SetupField(
      'event',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Event date', 'Ngày sự kiện'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Preparation areas', 'Các mảng chuẩn bị'),
      help: L10n(
        'Each area becomes a category for preparation cards.',
        'Mỗi mảng thành một nhóm cho các thẻ chuẩn bị.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Venue', 'Địa điểm'),
        L10n('Food', 'Đồ ăn'),
        L10n('Guests', 'Khách mời'),
        L10n('Decor', 'Trang trí'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Plan the table arrangement', 'Lên cách bố trí bàn'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Sketch the space', 'Phác thảo không gian'),
        L10n('Leave clear walkways', 'Chừa lối đi thông thoáng'),
      ],
      done: 1,
      cover: 'events.garden-table',
    ),
    SampleCard(
      L10n('Choose a few simple dishes', 'Chọn vài món đơn giản'),
      column: 0,
      category: 1,
      dueOffset: -5,
      anchor: 'event',
    ),
    SampleCard(
      L10n('Prepare the welcome sign', 'Chuẩn bị bảng chào'),
      column: 0,
      category: 3,
      cover: 'events.paper-lanterns',
      dueOffset: -1,
      anchor: 'event',
    ),
  ],
);

const _goals90 = BoardTemplate(
  id: 'goals-90',
  pro: true,
  group: TemplateGroup.personal,
  name: L10n('90-Day Goals', 'Mục tiêu 90 ngày'),
  goal: L10n(
    'Break the next 90 days into actions you can finish.',
    'Chia 90 ngày tới thành các việc có thể hoàn thành.',
  ),
  example: L10n(
    'Finish a chapter, make a prototype, clear one space.',
    'Hoàn thành một chương, làm mẫu thử, dọn một góc nhà.',
  ),
  tags: ['goals', '90 days', 'milestones', 'mục tiêu', '90 ngày', 'cột mốc'],
  cover: 'goals.target-rings',
  look: 'orchard',
  hues: [3, 6, 0, 2],
  time: TimePreset('month', pinned: false),
  columns: [
    TemplateColumn(L10n('Planned', 'Dự định')),
    TemplateColumn(L10n('Doing', 'Đang làm')),
    TemplateColumn(L10n('Achieved', 'Đạt được'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Plan title', 'Tên kế hoạch'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('My next 90 days', '90 ngày tới của tôi'),
    ),
    SetupField(
      'plan',
      FieldKind.dateRange,
      FieldRole.milestone,
      label: L10n('Plan starts', 'Kế hoạch bắt đầu'),
      help: L10n(
        'Adds the plan’s start and end as key dates on the board.',
        'Thêm ngày bắt đầu và kết thúc kế hoạch làm ngày quan trọng trên bảng.',
      ),
      endLabel: L10n('Plan ends', 'Kế hoạch kết thúc'),
      dateDefault: 'today',
      rangeDays: 90,
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Goal areas', 'Các mảng mục tiêu'),
      help: L10n(
        'Each area becomes a category, with cards for milestone actions you '
            'can finish.',
        'Mỗi mảng thành một nhóm, với các thẻ ghi việc cụ thể có thể hoàn '
            'thành để đạt cột mốc.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Learning', 'Học tập'),
        L10n('Personal project', 'Dự án cá nhân'),
        L10n('Home', 'Nhà cửa'),
      ],
    ),
    _timeMonth,
  ],
  samples: [
    SampleCard(
      L10n('Finish one introductory chapter', 'Học xong một chương nhập môn'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Read the chapter', 'Đọc chương'),
        L10n('Complete one exercise', 'Làm một bài tập'),
        L10n('Write a summary', 'Viết tóm tắt'),
      ],
      done: 1,
      cover: 'goals.sunrise-stairs',
      dueOffset: 14,
      anchor: 'plan',
    ),
    SampleCard(
      L10n(
        'Build a small working prototype',
        'Làm mẫu thử nhỏ có thể chạy được',
      ),
      column: 0,
      category: 1,
      dueOffset: -14,
      anchor: 'plan.end',
    ),
    SampleCard(
      L10n('Clear one unused shelf', 'Dọn một kệ ít dùng'),
      column: 0,
      category: 2,
    ),
  ],
);

const _homeOrganization = BoardTemplate(
  id: 'home-organization',
  pro: true,
  group: TemplateGroup.personal,
  name: L10n('Home Organization', 'Sắp xếp nhà cửa'),
  goal: L10n(
    'Give each space a manageable next task.',
    'Chọn việc vừa sức tiếp theo cho từng không gian.',
  ),
  example: L10n(
    'Sort a drawer, arrange a shelf, refresh a corner.',
    'Phân loại đồ trong ngăn kéo, xếp lại kệ, làm mới một góc nhà.',
  ),
  tags: ['home', 'organize', 'declutter', 'nhà cửa', 'sắp xếp', 'dọn đồ'],
  cover: 'home.quilt-blocks',
  look: 'linen',
  hues: [2, 6, 3, 1],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('To sort', 'Cần phân loại')),
    TemplateColumn(L10n('Organizing', 'Đang sắp xếp')),
    TemplateColumn(L10n('Review', 'Cần xem lại')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Board title', 'Tên bảng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('A more orderly home', 'Nhà cửa gọn gàng hơn'),
    ),
    SetupField(
      'rooms',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Rooms', 'Các phòng'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a room', 'Thêm phòng'),
      chipsDefault: [
        L10n('Living room', 'Phòng khách'),
        L10n('Bedroom', 'Phòng ngủ'),
        L10n('Kitchen', 'Bếp'),
      ],
    ),
    SetupField(
      'focus',
      FieldKind.select,
      FieldRole.sampleSet,
      label: L10n('Tidy-up focus', 'Trọng tâm dọn dẹp'),
      help: L10n(
        'Only picks the example cards offered with this board.',
        'Chỉ chọn các thẻ ví dụ được gợi ý cho bảng này.',
      ),
      options: [
        SetupOption('declutter', L10n('Declutter', 'Bớt đồ dư')),
        SetupOption('organize', L10n('Organize', 'Sắp xếp')),
        SetupOption('refresh', L10n('Refresh', 'Làm mới')),
      ],
      optionDefault: 'declutter',
    ),
  ],
  samples: [
    SampleCard(
      L10n(
        'Sort the living room drawer',
        'Phân loại đồ trong ngăn kéo phòng khách',
      ),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Empty the drawer', 'Lấy hết đồ trong ngăn ra'),
        L10n('Separate useful items', 'Để riêng đồ còn dùng'),
        L10n('Set aside what can leave', 'Để riêng đồ có thể bỏ bớt'),
      ],
      done: 1,
      cover: 'home.woven-linen',
      set: 'declutter',
    ),
    SampleCard(
      L10n('Arrange the kitchen shelf', 'Sắp xếp kệ bếp'),
      column: 0,
      category: 2,
      subtasks: [
        L10n('Group similar items', 'Gom đồ cùng loại'),
        L10n(
          'Place frequent items within reach',
          'Đặt đồ hay dùng ở chỗ dễ lấy',
        ),
      ],
      done: 0,
      cover: 'home.courtyard',
      set: 'organize',
    ),
    SampleCard(
      L10n('Refresh the reading corner', 'Làm mới góc đọc sách'),
      column: 0,
      category: 1,
      subtasks: [
        L10n('Clear the surface', 'Dọn mặt bàn'),
        L10n('Rearrange the light and books', 'Sắp lại đèn và sách'),
      ],
      done: 0,
      cover: 'home.reading-corner',
      set: 'refresh',
    ),
  ],
);

// ─── D. Creative projects ────────────────────────────────────────────────

const _content = BoardTemplate(
  id: 'content',
  pro: false,
  group: TemplateGroup.creative,
  name: L10n('Content Planner', 'Kế hoạch nội dung'),
  goal: L10n(
    'Follow each piece from an idea to publication.',
    'Theo dõi từng nội dung từ ý tưởng tới đăng tải.',
  ),
  example: L10n(
    'A short video, a photo post and a story outline.',
    'Video ngắn, bài đăng ảnh và dàn ý tin ngắn.',
  ),
  tags: ['content', 'creator', 'posts', 'nội dung', 'sáng tạo', 'bài đăng'],
  cover: 'creative.paper-collage',
  look: 'paper',
  hues: [4, 2, 6, 0],
  time: TimePreset('week', pinned: true),
  columns: [
    TemplateColumn(L10n('Ideas', 'Ý tưởng')),
    TemplateColumn(L10n('Creating', 'Đang làm')),
    TemplateColumn(L10n('Ready', 'Sẵn sàng')),
    TemplateColumn(L10n('Published', 'Đã đăng'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Channel or project name', 'Tên kênh hoặc dự án'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Content ideas', 'Ý tưởng nội dung'),
    ),
    SetupField(
      'formats',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Platforms or formats', 'Nền tảng hoặc định dạng'),
      help: L10n(
        'Each becomes a category on a manual Kanban board that never posts or '
            'schedules anything.',
        'Mỗi mục thành một nhóm trên bảng Kanban thủ công, không tự đăng hay '
            'hẹn giờ đăng nội dung.',
      ),
      placeholder: L10n('Add a format', 'Thêm định dạng'),
      chipsDefault: [
        L10n('Short video', 'Video ngắn'),
        L10n('Post', 'Bài đăng'),
        L10n('Photo', 'Ảnh'),
        L10n('Story', 'Tin ngắn'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Show a simple desk setup', 'Giới thiệu góc bàn đơn giản'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Write three talking points', 'Viết ba ý chính'),
        L10n('Record a short clip', 'Quay đoạn ngắn'),
        L10n('Check the captions', 'Kiểm tra phụ đề'),
      ],
      done: 1,
      cover: 'work.desk-light',
      dueOffset: 3,
    ),
    SampleCard(
      L10n('Share a useful tip', 'Chia sẻ một mẹo hữu ích'),
      column: 0,
      category: 1,
    ),
    SampleCard(
      L10n('Choose a photo for a short story', 'Chọn ảnh cho một tin ngắn'),
      column: 2,
      category: 3,
      cover: 'creative.cutout-garden',
      dueOffset: 5,
    ),
  ],
);

const _photography = BoardTemplate(
  id: 'photography',
  pro: true,
  group: TemplateGroup.creative,
  name: L10n('Photography Workflow', 'Quy trình nhiếp ảnh'),
  goal: L10n(
    'Take a shoot from preparation to the delivered set.',
    'Đưa buổi chụp từ chuẩn bị tới bàn giao bộ ảnh.',
  ),
  example: L10n(
    'A shot list, a lighting check and a final photo selection.',
    'Danh sách ảnh cần chụp, kiểm tra ánh sáng và chọn ảnh cuối.',
  ),
  tags: [
    'photography',
    'shoot',
    'editing',
    'nhiếp ảnh',
    'chụp ảnh',
    'chỉnh ảnh',
  ],
  cover: 'abstract.folded-rhythm',
  look: 'dusk',
  hues: [5, 0, 4, 2],
  time: TimePreset('week', pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('Planning', 'Lên kế hoạch')),
    TemplateColumn(L10n('Shooting', 'Đang chụp')),
    TemplateColumn(L10n('Editing', 'Đang chỉnh ảnh')),
    TemplateColumn(L10n('Delivered', 'Đã bàn giao'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Shoot title', 'Tên buổi chụp'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New photo shoot', 'Buổi chụp mới'),
    ),
    SetupField(
      'shoot',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Shoot date', 'Ngày chụp'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'groups',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Work groups', 'Nhóm công việc'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Preparation', 'Chuẩn bị'),
        L10n('Shooting', 'Chụp ảnh'),
        L10n('Edit', 'Chỉnh ảnh'),
        L10n('Delivery', 'Bàn giao'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Prepare a short shot list', 'Chuẩn bị danh sách ảnh cần chụp'),
      column: 0,
      category: 0,
      subtasks: [
        L10n('Choose the subject', 'Chọn chủ thể'),
        L10n('List three compositions', 'Liệt kê ba bố cục'),
        L10n('Note the light needed', 'Ghi ánh sáng cần có'),
      ],
      done: 1,
      cover: 'creative.ceramic-studio',
      dueOffset: -2,
      anchor: 'shoot',
    ),
    SampleCard(
      L10n(
        'Try window light on one subject',
        'Thử ánh sáng cửa sổ với một chủ thể',
      ),
      column: 1,
      category: 1,
      cover: 'home.arched-window',
    ),
    SampleCard(
      L10n('Select and export a small set', 'Chọn và xuất một bộ ảnh nhỏ'),
      column: 2,
      category: 3,
      dueOffset: 3,
      anchor: 'shoot',
    ),
  ],
);

const _inspiration = BoardTemplate(
  id: 'inspiration',
  pro: false,
  group: TemplateGroup.creative,
  name: L10n('Inspiration Board', 'Bảng cảm hứng'),
  goal: L10n(
    'Keep visual references close to the ideas they spark.',
    'Giữ tư liệu hình ảnh cạnh những ý tưởng được gợi ra.',
  ),
  example: L10n(
    'Colour studies, material notes and shapes to explore.',
    'Thử màu, ghi chú chất liệu và hình khối để tìm hiểu.',
  ),
  tags: [
    'inspiration',
    'references',
    'moodboard',
    'cảm hứng',
    'tham khảo',
    'ý tưởng',
  ],
  cover: 'creative.paint-palette',
  look: 'clay',
  hues: [6, 4, 2, 3],
  time: TimePreset('week', pinned: false),
  presentation: 'detailed',
  columns: [
    TemplateColumn(L10n('Collected', 'Đã sưu tầm')),
    TemplateColumn(L10n('Exploring', 'Đang tìm hiểu')),
    TemplateColumn(L10n('Selected', 'Đã chọn')),
    TemplateColumn(L10n('Applied', 'Đã áp dụng'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Collection title', 'Tên bộ sưu tập'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Collected inspiration', 'Góp nhặt cảm hứng'),
    ),
    SetupField(
      'themes',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Themes', 'Chủ đề'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a theme', 'Thêm chủ đề'),
      chipsDefault: [
        L10n('Colours', 'Màu sắc'),
        L10n('Materials', 'Chất liệu'),
        L10n('Shapes', 'Hình khối'),
        L10n('Spaces', 'Không gian'),
      ],
    ),
    SetupField(
      'style',
      FieldKind.select,
      FieldRole.presentation,
      label: L10n('Card style', 'Kiểu thẻ'),
      help: L10n(
        'Changes how much of each card and its cover is shown.',
        'Đổi lượng nội dung và ảnh bìa hiển thị trên mỗi thẻ.',
      ),
      options: [
        SetupOption(
          'detailed',
          L10n('Expanded covers', 'Ảnh bìa mở rộng'),
          presentation: 'detailed',
        ),
        SetupOption('compact', L10n('Compact', 'Gọn'), presentation: 'compact'),
      ],
      optionDefault: 'detailed',
    ),
  ],
  samples: [
    SampleCard(
      L10n('Explore warm and cool colours', 'Tìm hiểu màu ấm và màu lạnh'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Pick three colours', 'Chọn ba màu'),
        L10n('Try them in one composition', 'Thử ghép trong một bố cục'),
      ],
      done: 1,
      cover: 'creative.paper-collage',
    ),
    SampleCard(
      L10n('Notice the texture of woven fabric', 'Quan sát bề mặt vải dệt'),
      column: 0,
      category: 1,
      cover: 'home.woven-linen',
    ),
    SampleCard(
      L10n('Try a layout with arches', 'Thử bố cục có hình vòm'),
      column: 2,
      category: 2,
      cover: 'travel.city-arches',
    ),
  ],
);

const _writing = BoardTemplate(
  id: 'writing',
  pro: true,
  group: TemplateGroup.creative,
  name: L10n('Writing Project', 'Dự án viết'),
  goal: L10n(
    'Move a piece of writing from notes to the finished draft.',
    'Đưa bài viết từ ghi chú tới bản hoàn chỉnh.',
  ),
  example: L10n(
    'A scene outline, a first chapter and an editing pass.',
    'Dàn ý một cảnh, chương đầu và lượt biên tập.',
  ),
  tags: ['writing', 'draft', 'chapters', 'viết', 'bản thảo', 'chương'],
  cover: 'creative.printing-blocks',
  look: 'sand',
  hues: [2, 6, 4, 0],
  time: TimePreset('week', pinned: false),
  columns: [
    TemplateColumn(L10n('Ideas', 'Ý tưởng')),
    TemplateColumn(L10n('Drafting', 'Đang viết')),
    TemplateColumn(L10n('Editing', 'Đang biên tập')),
    TemplateColumn(L10n('Finished', 'Hoàn thành'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Project title', 'Tên dự án'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New writing project', 'Dự án viết mới'),
    ),
    SetupField(
      'sections',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Sections or chapters', 'Các phần hoặc chương'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a section', 'Thêm phần'),
      chipsDefault: [
        L10n('Opening', 'Mở đầu'),
        L10n('Middle', 'Phần giữa'),
        L10n('Ending', 'Kết thúc'),
      ],
    ),
    SetupField(
      'finish',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Finish-by date', 'Ngày cần viết xong'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
  ],
  samples: [
    SampleCard(
      L10n('Draft an opening scene', 'Viết nháp cảnh mở đầu'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Choose a point of view', 'Chọn góc nhìn'),
        L10n('Write the first paragraph', 'Viết đoạn đầu'),
        L10n('Read it aloud', 'Đọc thành tiếng'),
      ],
      done: 1,
      cover: 'study.open-book',
    ),
    SampleCard(
      L10n('Outline the turning point', 'Lập dàn ý cho bước ngoặt'),
      column: 0,
      category: 1,
    ),
    SampleCard(
      L10n('Check the final paragraph', 'Kiểm tra đoạn kết'),
      column: 2,
      category: 2,
      dueOffset: -2,
      anchor: 'finish',
    ),
  ],
);

const _gameDev = BoardTemplate(
  id: 'game-dev',
  pro: true,
  group: TemplateGroup.creative,
  name: L10n('Game Development', 'Phát triển trò chơi'),
  goal: L10n(
    'Bring one small game feature through building and testing.',
    'Đưa từng tính năng nhỏ của trò chơi qua xây dựng và kiểm thử.',
  ),
  example: L10n(
    'A movement prototype, an interface sketch and a sound test.',
    'Mẫu thử di chuyển, phác thảo giao diện và thử âm thanh.',
  ),
  tags: [
    'game',
    'development',
    'prototype',
    'trò chơi',
    'phát triển',
    'mẫu thử',
  ],
  cover: 'abstract.offset-checks',
  look: 'ink',
  hues: [5, 1, 4, 3, 0],
  time: TimePreset('week', count: 2, pinned: false),
  columns: [
    TemplateColumn(L10n('Backlog', 'Việc chờ')),
    TemplateColumn(L10n('Building', 'Đang xây dựng')),
    TemplateColumn(L10n('Testing', 'Đang kiểm thử')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Game name', 'Tên trò chơi'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Small game project', 'Dự án trò chơi nhỏ'),
    ),
    SetupField(
      'workstreams',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Workstreams', 'Các mảng việc'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Gameplay', 'Lối chơi'),
        L10n('Art', 'Hình ảnh'),
        L10n('UI', 'Giao diện'),
        L10n('Audio', 'Âm thanh'),
        L10n('QA', 'Kiểm thử'),
      ],
    ),
    SetupField(
      'milestone',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Milestone date', 'Ngày cột mốc'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
  ],
  samples: [
    SampleCard(
      L10n('Prototype a movement loop', 'Làm mẫu thử vòng lặp di chuyển'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Move a placeholder shape', 'Di chuyển hình tạm'),
        L10n('Add a stop condition', 'Thêm điều kiện dừng'),
        L10n('Try the controls', 'Thử điều khiển'),
      ],
      done: 1,
      cover: 'abstract.split-circle',
    ),
    SampleCard(
      L10n('Sketch the pause menu', 'Phác thảo trình đơn tạm dừng'),
      column: 0,
      category: 2,
    ),
    SampleCard(
      L10n(
        'Check one complete play session',
        'Kiểm tra một lượt chơi trọn vẹn',
      ),
      column: 2,
      category: 4,
      dueOffset: -1,
      anchor: 'milestone',
    ),
  ],
);

const _campaign = BoardTemplate(
  id: 'campaign',
  pro: true,
  group: TemplateGroup.creative,
  name: L10n('Social Campaign', 'Chiến dịch truyền thông'),
  goal: L10n(
    'One campaign, several channels, released on one rhythm.',
    'Một chiến dịch, nhiều kênh, ra bài theo cùng một nhịp.',
  ),
  example: L10n(
    'A short video, a photo post and a story outline.',
    'Video ngắn, bài đăng ảnh và dàn ý tin ngắn.',
  ),
  tags: ['content', 'creator', 'posts', 'nội dung', 'sáng tạo', 'bài đăng'],
  cover: 'creative.ribbon-weave',
  look: 'paper',
  hues: [4, 2, 6, 0],
  time: TimePreset('week', pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('Ideas', 'Ý tưởng')),
    TemplateColumn(L10n('Producing', 'Đang sản xuất')),
    TemplateColumn(L10n('Reviewing', 'Đang duyệt')),
    TemplateColumn(L10n('Published', 'Đã đăng'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Campaign name', 'Tên chiến dịch'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New campaign', 'Chiến dịch mới'),
    ),
    SetupField(
      'themes',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Channels or themes', 'Kênh hoặc chủ đề'),
      help: L10n(
        'Each becomes a category on a manual Kanban board that never posts or '
            'schedules anything.',
        'Mỗi mục thành một nhóm trên bảng Kanban thủ công, không tự đăng hay '
            'hẹn giờ đăng nội dung.',
      ),
      placeholder: L10n('Add a theme', 'Thêm chủ đề'),
      chipsDefault: [
        L10n('Introduction', 'Giới thiệu'),
        L10n('Behind the scenes', 'Hậu trường'),
        L10n('Highlights', 'Điểm nổi bật'),
      ],
    ),
    SetupField(
      'campaign',
      FieldKind.dateRange,
      FieldRole.milestone,
      label: L10n('Campaign starts', 'Chiến dịch bắt đầu'),
      help: L10n(
        'Adds the campaign’s start and end as key dates on the '
            'board.',
        'Không bắt buộc; thêm ngày bắt đầu và kết thúc chiến dịch làm ngày '
            'quan trọng trên bảng.',
      ),
      endLabel: L10n('Campaign ends', 'Chiến dịch kết thúc'),
    ),
    _timeWeek,
  ],
  samples: [
    SampleCard(
      L10n(
        'Draft the campaign’s opening message',
        'Soạn thông điệp mở đầu chiến dịch',
      ),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Choose one main point', 'Chọn một ý chính'),
        L10n('Write two short versions', 'Viết hai phiên bản ngắn'),
        L10n('Check the wording', 'Kiểm tra câu chữ'),
      ],
      done: 1,
      cover: 'events.confetti-cutouts',
      dueOffset: 0,
      anchor: 'campaign',
    ),
    SampleCard(
      L10n(
        'Prepare a behind-the-scenes sequence',
        'Chuẩn bị chuỗi nội dung hậu trường',
      ),
      column: 0,
      category: 1,
      cover: 'creative.ceramic-studio',
    ),
    SampleCard(
      L10n(
        'Review the closing highlights',
        'Duyệt nội dung nổi bật để khép lại chiến dịch',
      ),
      column: 2,
      category: 2,
      cover: 'events.stage-curtain',
      dueOffset: -1,
      anchor: 'campaign.end',
    ),
  ],
);

// ─── E. Planning & occasions ─────────────────────────────────────────────

const _trip = BoardTemplate(
  id: 'trip',
  pro: false,
  group: TemplateGroup.planning,
  name: L10n('Trip Preparation', 'Chuẩn bị chuyến đi'),
  goal: L10n(
    'Get the essentials ready before you leave.',
    'Chuẩn bị những việc cần thiết trước khi lên đường.',
  ),
  example: L10n(
    'Documents to check, a packing list and booking details to review.',
    'Giấy tờ cần kiểm tra, đồ cần mang và thông tin đặt chỗ cần xem lại.',
  ),
  tags: ['trip', 'travel', 'packing', 'chuyến đi', 'du lịch', 'hành lý'],
  cover: 'travel.coastal-route',
  look: 'mist',
  hues: [0, 3, 2, 4],
  time: TimePreset('week', count: 2, pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('To arrange', 'Cần sắp xếp')),
    TemplateColumn(L10n('In progress', 'Đang làm')),
    TemplateColumn(L10n('Confirmed', 'Đã xác nhận')),
    TemplateColumn(L10n('Ready', 'Sẵn sàng'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Trip name', 'Tên chuyến đi'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Next trip', 'Chuyến đi tới'),
    ),
    SetupField(
      'departure',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Departure date', 'Ngày khởi hành'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Areas', 'Các mảng chuẩn bị'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Documents', 'Giấy tờ'),
        L10n('Packing', 'Hành lý'),
        L10n('Bookings', 'Đặt chỗ'),
        L10n('Other', 'Khác'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Check the travel documents', 'Kiểm tra giấy tờ cho chuyến đi'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('List the documents needed', 'Liệt kê giấy tờ cần mang'),
        L10n('Check validity', 'Kiểm tra thời hạn'),
        L10n('Keep copies together', 'Để bản sao cùng một chỗ'),
      ],
      done: 1,
      cover: 'travel.city-arches',
      dueOffset: -7,
      anchor: 'departure',
    ),
    SampleCard(
      L10n('Pack a small day bag', 'Soạn túi nhỏ dùng trong ngày'),
      column: 0,
      category: 1,
      dueOffset: -1,
      anchor: 'departure',
    ),
    SampleCard(
      L10n(
        'Review the saved booking details',
        'Xem lại thông tin đặt chỗ đã lưu',
      ),
      column: 0,
      category: 2,
      cover: 'travel.mountain-pass',
    ),
  ],
);

const _monthly = BoardTemplate(
  id: 'monthly',
  pro: false,
  group: TemplateGroup.planning,
  name: L10n('Monthly Planner', 'Kế hoạch tháng'),
  goal: L10n(
    'See this month’s tasks by progress and date.',
    'Xem việc trong tháng theo tiến độ và ngày hạn.',
  ),
  example: L10n(
    'A project step, some paperwork and a home task.',
    'Một bước của dự án, việc giấy tờ và việc nhà.',
  ),
  tags: ['monthly', 'month', 'planning', 'tháng', 'kế hoạch', 'sắp xếp'],
  cover: 'abstract.terrace-lines',
  look: 'paper',
  hues: [1, 3, 4, 2],
  time: TimePreset('month', pinned: true),
  columns: [
    TemplateColumn(L10n('Planned', 'Dự định')),
    TemplateColumn(L10n('Doing', 'Đang làm')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Plan name', 'Tên kế hoạch'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('This month', 'Tháng này'),
    ),
    SetupField(
      'month',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Month starts', 'Tháng bắt đầu'),
      help: L10n(
        'Adds the target month’s first day as a key date on the board.',
        'Thêm ngày đầu của tháng đã chọn làm ngày quan trọng trên bảng.',
      ),
      dateDefault: 'monthStart',
    ),
    SetupField(
      'categories',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Categories', 'Các nhóm'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a category', 'Thêm nhóm'),
      chipsDefault: [
        L10n('Projects', 'Dự án'),
        L10n('Paperwork', 'Giấy tờ'),
        L10n('Home', 'Nhà cửa'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n(
        'Choose a project step for the month',
        'Chọn một bước dự án cho tháng này',
      ),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Review the open work', 'Xem lại việc chưa xong'),
        L10n('Pick one concrete result', 'Chọn một kết quả cụ thể'),
      ],
      done: 1,
      cover: 'goals.stepping-stones',
      dueOffset: 3,
      anchor: 'month',
    ),
    SampleCard(
      L10n('Sort the document folder', 'Sắp xếp thư mục giấy tờ'),
      column: 0,
      category: 1,
      dueOffset: 10,
      anchor: 'month',
    ),
    SampleCard(
      L10n('Clear one kitchen shelf', 'Dọn một kệ bếp'),
      column: 0,
      category: 2,
    ),
  ],
);

const _daily = BoardTemplate(
  id: 'daily',
  pro: false,
  group: TemplateGroup.planning,
  name: L10n('Daily Focus', 'Việc trọng tâm hôm nay'),
  goal: L10n(
    'A small set of tasks for the day ahead.',
    'Vài việc cần tập trung cho ngày phía trước.',
  ),
  example: L10n(
    'Finish a draft, sort a drawer, read a short lesson.',
    'Xong bản nháp, dọn ngăn kéo, đọc một bài học ngắn.',
  ),
  tags: ['daily', 'focus', 'today', 'hằng ngày', 'tập trung', 'hôm nay'],
  cover: 'wellness.tea-ritual',
  look: 'sage',
  hues: [3, 2, 1, 4],
  time: TimePreset('day', pinned: true, open: true),
  columns: [
    TemplateColumn(L10n('Planned', 'Dự định')),
    TemplateColumn(L10n('In progress', 'Đang làm')),
    TemplateColumn(L10n('Finished', 'Hoàn thành'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Title', 'Tên bảng'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Today\'s focus', 'Việc trọng tâm hôm nay'),
    ),
    SetupField(
      'day',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Focus day', 'Ngày tập trung'),
      help: L10n(
        'Adds the chosen day as a key date on the board.',
        'Thêm ngày đã chọn làm ngày quan trọng trên bảng.',
      ),
      dateDefault: 'today',
    ),
    SetupField(
      'areas',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Main areas', 'Các mảng chính'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Work', 'Công việc'),
        L10n('Home', 'Nhà cửa'),
        L10n('Learning', 'Học tập'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Finish a short draft', 'Hoàn thành bản nháp ngắn'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Write the missing paragraph', 'Viết đoạn còn thiếu'),
        L10n('Read it through', 'Đọc lại toàn bài'),
      ],
      done: 1,
      cover: 'work.desk-light',
      dueOffset: 0,
      anchor: 'day',
    ),
    SampleCard(
      L10n('Sort one small drawer', 'Dọn một ngăn kéo nhỏ'),
      column: 0,
      category: 1,
      dueOffset: 0,
      anchor: 'day',
    ),
    SampleCard(
      L10n('Read a short lesson', 'Đọc một bài học ngắn'),
      column: 0,
      category: 2,
      dueOffset: 0,
      anchor: 'day',
    ),
  ],
);

const _workshop = BoardTemplate(
  id: 'workshop',
  pro: true,
  group: TemplateGroup.planning,
  name: L10n('Workshop Preparation', 'Chuẩn bị workshop'),
  goal: L10n(
    'Bring the materials, equipment and space together.',
    'Chuẩn bị đầy đủ tài liệu, thiết bị và không gian.',
  ),
  example: L10n(
    'A practice activity, an equipment check and arrival notes.',
    'Hoạt động thực hành, kiểm tra thiết bị và hướng dẫn đến nơi.',
  ),
  tags: [
    'workshop',
    'preparation',
    'materials',
    'buổi thực hành',
    'chuẩn bị',
    'tài liệu',
  ],
  cover: 'creative.ceramic-studio',
  look: 'terracotta',
  hues: [6, 2, 0, 3],
  time: TimePreset('week', pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('To prepare', 'Cần chuẩn bị')),
    TemplateColumn(L10n('Building', 'Đang soạn')),
    TemplateColumn(L10n('Confirming', 'Đang xác nhận')),
    TemplateColumn(L10n('Ready', 'Sẵn sàng'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Workshop name', 'Tên buổi thực hành'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('New workshop', 'Buổi thực hành mới'),
    ),
    SetupField(
      'event',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Event date', 'Ngày tổ chức'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'groups',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Preparation groups', 'Nhóm chuẩn bị'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Content', 'Nội dung'),
        L10n('Equipment', 'Thiết bị'),
        L10n('Venue', 'Địa điểm'),
        L10n('Communication', 'Thông tin'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n(
        'Build a short practice activity',
        'Soạn một hoạt động thực hành ngắn',
      ),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Write the instructions', 'Viết hướng dẫn'),
        L10n('Try the activity once', 'Làm thử một lượt'),
        L10n('Prepare an example', 'Chuẩn bị ví dụ'),
      ],
      done: 1,
      cover: 'creative.printing-blocks',
      dueOffset: -5,
      anchor: 'event',
    ),
    SampleCard(
      L10n('Check the equipment setup', 'Kiểm tra bố trí thiết bị'),
      column: 2,
      category: 1,
      dueOffset: -2,
      anchor: 'event',
    ),
    SampleCard(
      L10n('Draft the arrival instructions', 'Soạn hướng dẫn đến nơi'),
      column: 0,
      category: 3,
    ),
  ],
);

const _moving = BoardTemplate(
  id: 'moving',
  pro: false,
  group: TemplateGroup.planning,
  name: L10n('Moving Home', 'Chuyển nhà'),
  goal: L10n(
    'Keep each box moving towards its new place.',
    'Theo dõi từng thùng đồ tới khi được xếp vào chỗ mới.',
  ),
  example: L10n(
    'Pack a room, label boxes and unpack the essentials.',
    'Đóng đồ trong phòng, dán nhãn thùng và mở đồ cần dùng trước.',
  ),
  tags: ['moving', 'home', 'packing', 'chuyển nhà', 'đóng đồ', 'dọn nhà'],
  cover: 'home.woven-linen',
  look: 'clay',
  hues: [2, 6, 0, 3],
  time: TimePreset('week', count: 2, pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('To pack', 'Cần đóng gói')),
    TemplateColumn(L10n('Packing', 'Đang đóng gói')),
    TemplateColumn(L10n('Transporting', 'Đang vận chuyển')),
    TemplateColumn(L10n('Unpacked', 'Đã mở và xếp đồ'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Move title', 'Tên đợt chuyển nhà'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('Moving to a new home', 'Chuyển tới nhà mới'),
    ),
    SetupField(
      'moving',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Moving day', 'Ngày chuyển nhà'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'rooms',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Rooms', 'Các phòng'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add a room', 'Thêm phòng'),
      chipsDefault: [
        L10n('Living room', 'Phòng khách'),
        L10n('Bedroom', 'Phòng ngủ'),
        L10n('Kitchen', 'Bếp'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Pack the living room books', 'Đóng gói sách phòng khách'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Sort the books', 'Sắp xếp sách'),
        L10n('Pack in small boxes', 'Đóng vào thùng nhỏ'),
        L10n('Label the room', 'Ghi nhãn phòng'),
      ],
      done: 1,
      cover: 'shopping.wrapped-parcel',
      dueOffset: -3,
      anchor: 'moving',
    ),
    SampleCard(
      L10n('Pack a first-night bag', 'Soạn túi đồ cho đêm đầu'),
      column: 0,
      category: 1,
      dueOffset: -1,
      anchor: 'moving',
    ),
    SampleCard(
      L10n('Unpack the everyday kitchen items', 'Mở và xếp đồ bếp thường dùng'),
      column: 0,
      category: 2,
      dueOffset: 1,
      anchor: 'moving',
    ),
  ],
);

const _holiday = BoardTemplate(
  id: 'holiday',
  pro: true,
  group: TemplateGroup.planning,
  name: L10n('Holiday Planner', 'Kế hoạch dịp lễ'),
  goal: L10n(
    'Keep the preparations together for a special occasion.',
    'Gom việc chuẩn bị cho một dịp đặc biệt.',
  ),
  example: L10n(
    'Prepare a gift, check travel details and make space at home.',
    'Chuẩn bị quà, kiểm tra việc đi lại và sắp xếp nhà cửa.',
  ),
  tags: ['holiday', 'occasion', 'preparation', 'dịp lễ', 'ngày lễ', 'chuẩn bị'],
  cover: 'events.confetti-cutouts',
  look: 'blush',
  hues: [4, 6, 2, 3],
  time: TimePreset('week', count: 2, pinned: false, pinIfDated: true),
  columns: [
    TemplateColumn(L10n('To plan', 'Cần lên kế hoạch')),
    TemplateColumn(L10n('Arranging', 'Đang sắp xếp')),
    TemplateColumn(L10n('Ready', 'Sẵn sàng')),
    TemplateColumn(L10n('Done', 'Xong'), done: true),
  ],
  fields: [
    SetupField(
      'title',
      FieldKind.text,
      FieldRole.title,
      label: L10n('Occasion name', 'Tên dịp lễ'),
      help: L10n('Shown at the top of the board.', 'Hiện ở đầu bảng.'),
      required: true,
      textDefault: L10n('A special occasion', 'Một dịp đặc biệt'),
    ),
    SetupField(
      'start',
      FieldKind.date,
      FieldRole.milestone,
      label: L10n('Occasion starts', 'Dịp lễ bắt đầu'),
      help: L10n(
        'Adds an optional key date on the board.',
        'Không bắt buộc; hiện thành ngày quan trọng trên bảng.',
      ),
    ),
    SetupField(
      'groups',
      FieldKind.chips,
      FieldRole.categories,
      label: L10n('Groups', 'Các nhóm'),
      help: L10n(
        'Each becomes a category that stays with a card in every column.',
        'Mỗi mục thành một nhóm mà thẻ giữ ở mọi cột.',
      ),
      placeholder: L10n('Add an area', 'Thêm mảng'),
      chipsDefault: [
        L10n('Gifts', 'Quà tặng'),
        L10n('Travel', 'Đi lại'),
        L10n('Home', 'Nhà cửa'),
        L10n('People', 'Mọi người'),
      ],
    ),
  ],
  samples: [
    SampleCard(
      L10n('Prepare a small handmade gift', 'Chuẩn bị món quà nhỏ tự làm'),
      column: 1,
      category: 0,
      subtasks: [
        L10n('Choose the materials', 'Chọn vật liệu'),
        L10n('Make the gift', 'Làm quà'),
        L10n('Wrap it', 'Gói quà'),
      ],
      done: 1,
      cover: 'events.ribbon-invite',
      dueOffset: -3,
      anchor: 'start',
    ),
    SampleCard(
      L10n('Check the travel details', 'Kiểm tra thông tin đi lại'),
      column: 0,
      category: 1,
      dueOffset: -5,
      anchor: 'start',
    ),
    SampleCard(
      L10n('Prepare a welcoming corner', 'Chuẩn bị góc đón khách'),
      column: 2,
      category: 2,
      cover: 'events.garden-table',
    ),
  ],
);

/// Every template, in gallery order within its group. Ids are stored on
/// boards as provenance: never rename or reuse one.
const boardTemplates = <BoardTemplate>[
  _semester,
  _groupAssignment,
  _examRevision,
  _course,
  _thesis,
  _language,
  _project,
  _weekly,
  _sprint,
  _ideas,
  _launch,
  _meeting,
  _personal,
  _shopping,
  _homeImprovement,
  _event,
  _goals90,
  _homeOrganization,
  _content,
  _photography,
  _inspiration,
  _writing,
  _gameDev,
  _campaign,
  _trip,
  _monthly,
  _daily,
  _workshop,
  _moving,
  _holiday,
];
