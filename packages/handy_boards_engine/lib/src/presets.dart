part of '../handy_boards_engine.dart';

class PresetCategory {
  final String nameEn, nameVi;

  /// Stable HandyPalette identity hue, 0 through 7.
  final int hue;

  /// Study boards: the subject's course code and credits.
  final String? code;
  final int credits;
  const PresetCategory({
    required this.nameEn,
    required this.nameVi,
    required this.hue,
    this.code,
    this.credits = 0,
  });
}

/// A weekly class of a study preset: subject (category index), weekday
/// 1 (Monday) to 7, start and end minutes, room.
class PresetClass {
  final int category, weekday, start, end;
  final String room;
  const PresetClass(
    this.category,
    this.weekday,
    this.start,
    this.end,
    this.room,
  );
}

/// An exam [inDays] after the board is made, at [minute] past midnight.
class PresetExam {
  final int inDays;
  final int? minute;
  final String room;
  const PresetExam(this.inDays, this.minute, this.room);
}

/// A product with its price in minor units (null: no price yet).
class PresetProduct {
  final int? price;
  final int qty;
  final String store;
  final num? size;
  final String? unit;
  const PresetProduct(
    this.price, {
    this.qty = 1,
    this.store = '',
    this.size,
    this.unit,
  });
}

/// A post: format, platforms, an optional slot [inDays] ahead at [minute],
/// or a published record [publishedDaysAgo] (never with a made-up link).
class PresetPost {
  final String format;
  final List<String> platforms;
  final int? inDays, minute, publishedDaysAgo;
  const PresetPost(
    this.format,
    this.platforms, {
    this.inDays,
    this.minute,
    this.publishedDaysAgo,
  });
}

class PresetCard {
  final String titleEn, titleVi;
  final String noteEn, noteVi;
  final int column;
  final int? category;
  final List<(String, String)> subtasks;

  /// The first [done] subtasks start checked.
  final int done;
  final String? cover;

  /// Calendar days relative to the board's creation date.
  final int? dueInDays;
  final PresetExam? exam;
  final PresetProduct? product;
  final PresetPost? post;
  const PresetCard({
    required this.titleEn,
    required this.titleVi,
    required this.column,
    this.noteEn = '',
    this.noteVi = '',
    this.category,
    this.subtasks = const [],
    this.done = 0,
    this.cover,
    this.dueInDays,
    this.exam,
    this.product,
    this.post,
  });
}

class TemplatePreset {
  final String id;
  final String nameEn, nameVi, blurbEn, blurbVi;
  final bool pro;
  final String cover;
  final List<(String, String)> columns;
  final List<PresetCategory> categories;
  final List<PresetCard> cards;

  /// The board type it makes (see [boardTypes]).
  final String type;

  /// Column stages for shopping and content boards, one per column.
  final List<String>? stages;
  final List<PresetClass> classes;

  /// Study: the term runs this many weeks from the creation week's Monday.
  final int? termWeeks;

  /// Shopping: a budget in VND.
  final int? budget;
  const TemplatePreset({
    this.type = 'standard',
    this.stages,
    this.classes = const [],
    this.termWeeks,
    this.budget,
    required this.id,
    required this.nameEn,
    required this.nameVi,
    required this.blurbEn,
    required this.blurbVi,
    required this.pro,
    required this.cover,
    required this.columns,
    required this.categories,
    required this.cards,
  });
}

/// Opt-in sample content. Applying a preset must create fresh board/card IDs.
const List<TemplatePreset> templatePresets = [
  TemplatePreset(
    id: 'blank',
    nameEn: 'Blank Kanban',
    nameVi: 'Bảng trống',
    blurbEn: 'Start a board with three simple columns.',
    blurbVi: 'Bắt đầu với ba cột để sắp xếp công việc theo cách của bạn.',
    pro: false,
    cover: 'abstract.balanced-forms',
    columns: [('To Do', 'Cần làm'), ('Doing', 'Đang làm'), ('Done', 'Xong')],
    categories: [],
    cards: [],
  ),
  TemplatePreset(
    id: 'personal',
    nameEn: 'Personal tasks',
    nameVi: 'Việc cá nhân',
    blurbEn: 'Make room for errands, home tasks and time for yourself.',
    blurbVi: 'Sắp xếp việc vặt, việc nhà và thời gian cho bản thân.',
    pro: false,
    cover: 'home.arched-window',
    columns: [('To Do', 'Cần làm'), ('Doing', 'Đang làm'), ('Done', 'Xong')],
    categories: [
      PresetCategory(nameEn: 'Home', nameVi: 'Nhà cửa', hue: 1),
      PresetCategory(nameEn: 'Admin', nameVi: 'Giấy tờ', hue: 0),
      PresetCategory(nameEn: 'Wellbeing', nameVi: 'Chăm sóc bản thân', hue: 4),
      PresetCategory(nameEn: 'Learning', nameVi: 'Học thêm', hue: 2),
    ],
    cards: [
      PresetCard(
        titleEn: 'Clear one shelf in the hallway',
        titleVi: 'Dọn một ngăn kệ ở lối vào',
        column: 0,
        category: 0,
        subtasks: [
          ('Take everything off the shelf', 'Lấy hết đồ trên kệ'),
          ('Set aside things to donate', 'Để riêng đồ có thể cho tặng'),
          ('Wipe and put back the essentials', 'Lau kệ và xếp lại đồ cần dùng'),
        ],
        done: 0,
        cover: 'home.arched-window',
        dueInDays: 0,
      ),
      PresetCard(
        titleEn: 'Renew the library card',
        titleVi: 'Gia hạn thẻ thư viện',
        column: 0,
        category: 1,
        noteEn: 'Check which documents to bring before leaving home.',
        noteVi: 'Xem cần mang giấy tờ gì trước khi đi.',
        cover: 'study.open-book',
        dueInDays: 4,
      ),
      PresetCard(
        titleEn: 'Plan three easy evening meals',
        titleVi: 'Lên thực đơn ba bữa tối đơn giản',
        column: 1,
        category: 0,
        subtasks: [
          (
            'Check what is already in the kitchen',
            'Kiểm tra đồ sẵn có trong bếp',
          ),
          ('Choose three meals', 'Chọn ba món'),
          ('Write the missing ingredients', 'Ghi lại nguyên liệu còn thiếu'),
        ],
        done: 1,
        dueInDays: 1,
      ),
      PresetCard(
        titleEn: 'Walk a different route through the park',
        titleVi: 'Đi bộ một vòng mới trong công viên',
        column: 0,
        category: 2,
        cover: 'wellness.morning-leaves',
        dueInDays: 1,
      ),
      PresetCard(
        titleEn: 'Back up important household documents',
        titleVi: 'Sao lưu giấy tờ quan trọng của gia đình',
        column: 1,
        category: 1,
        subtasks: [
          ('Gather the files', 'Tập hợp các tệp'),
          ('Copy them to a second drive', 'Chép sang ổ lưu trữ thứ hai'),
          ('Open a few copies to check', 'Mở thử vài bản sao'),
        ],
        done: 1,
        dueInDays: 9,
      ),
      PresetCard(
        titleEn: 'Practise a new drawing exercise',
        titleVi: 'Thử một bài tập vẽ mới',
        column: 1,
        category: 3,
        noteEn: 'Spend twenty minutes sketching objects on the table.',
        noteVi: 'Dành hai mươi phút phác họa đồ vật trên bàn.',
        cover: 'creative.paper-collage',
        dueInDays: 2,
      ),
      PresetCard(
        titleEn: 'Book a bicycle service',
        titleVi: 'Đặt lịch bảo dưỡng xe đạp',
        column: 0,
        category: null,
        dueInDays: 6,
      ),
      PresetCard(
        titleEn: 'Prepare a small donation bag',
        titleVi: 'Soạn một túi đồ cho tặng',
        column: 2,
        category: 0,
        subtasks: [
          ('Choose clean items in good condition', 'Chọn đồ sạch còn dùng tốt'),
          ('Pack the bag', 'Xếp đồ vào túi'),
          ('Find a nearby drop-off point', 'Tìm điểm tiếp nhận gần nhà'),
        ],
        done: 3,
      ),
      PresetCard(
        titleEn: 'Choose a book for the month',
        titleVi: 'Chọn sách đọc trong tháng',
        column: 2,
        category: 3,
        cover: 'study.open-book',
      ),
      PresetCard(
        titleEn: 'Set a quieter evening routine',
        titleVi: 'Sắp xếp giờ nghỉ buổi tối',
        column: 2,
        category: 2,
        subtasks: [
          ('Pick a regular wind-down time', 'Chọn giờ bắt đầu nghỉ ngơi'),
          ('Put a book by the bed', 'Để sách cạnh giường'),
          ('Move the charger away from the bed', 'Đặt bộ sạc xa giường'),
        ],
        done: 3,
      ),
    ],
  ),
  TemplatePreset(
    id: 'project',
    nameEn: 'Project Kanban',
    nameVi: 'Theo dõi dự án',
    blurbEn:
        'Move a small project from the first idea through review to completion.',
    blurbVi: 'Đưa một dự án nhỏ từ ý tưởng qua bước kiểm tra đến hoàn thành.',
    pro: false,
    cover: 'work.folder-stack',
    columns: [
      ('Backlog', 'Chờ thực hiện'),
      ('In Progress', 'Đang thực hiện'),
      ('Review', 'Cần kiểm tra'),
      ('Done', 'Xong'),
    ],
    categories: [
      PresetCategory(nameEn: 'Planning', nameVi: 'Kế hoạch', hue: 1),
      PresetCategory(nameEn: 'Design', nameVi: 'Thiết kế', hue: 4),
      PresetCategory(nameEn: 'Build', nameVi: 'Thực hiện', hue: 0),
      PresetCategory(nameEn: 'Quality', nameVi: 'Chất lượng', hue: 2),
    ],
    cards: [
      PresetCard(
        titleEn: 'Agree on the first release scope',
        titleVi: 'Chốt phạm vi phiên bản đầu',
        column: 0,
        category: 0,
        subtasks: [
          ('List the essential outcomes', 'Liệt kê kết quả cần có'),
          ('Move optional ideas to later', 'Để ý tưởng chưa cần sang đợt sau'),
          ('Write a clear finish line', 'Ghi rõ tiêu chí hoàn thành'),
        ],
        done: 0,
        cover: 'work.folder-stack',
        dueInDays: 2,
      ),
      PresetCard(
        titleEn: 'Sketch the main user journey',
        titleVi: 'Phác thảo luồng sử dụng chính',
        column: 1,
        category: 1,
        subtasks: [
          ('Map the starting point', 'Xác định điểm bắt đầu'),
          ('Draw the key steps', 'Vẽ các bước chính'),
          ('Mark possible dead ends', 'Đánh dấu chỗ dễ bị mắc kẹt'),
        ],
        done: 1,
        cover: 'work.sticky-plan',
        dueInDays: 3,
      ),
      PresetCard(
        titleEn: 'Build the first working version',
        titleVi: 'Làm phiên bản chạy được đầu tiên',
        column: 1,
        category: 2,
        subtasks: [
          ('Prepare the basic structure', 'Chuẩn bị cấu trúc cơ bản'),
          ('Complete the main action', 'Làm xong thao tác chính'),
          ('Save and reopen a sample', 'Lưu rồi mở lại một mẫu'),
        ],
        done: 1,
        dueInDays: 0,
      ),
      PresetCard(
        titleEn: 'Review the empty and error states',
        titleVi: 'Kiểm tra trạng thái trống và lỗi',
        column: 2,
        category: 3,
        subtasks: [
          ('Try a new empty workspace', 'Thử với không gian làm việc trống'),
          ('Interrupt a save attempt', 'Thử ngắt một lần lưu'),
          ('Check the recovery message', 'Kiểm tra thông báo khôi phục'),
        ],
        done: 2,
        dueInDays: 5,
      ),
      PresetCard(
        titleEn: 'Collect feedback on the first draft',
        titleVi: 'Ghi nhận góp ý cho bản nháp đầu',
        column: 2,
        category: 1,
        noteEn: 'Keep observations separate from proposed fixes.',
        noteVi: 'Ghi riêng điều quan sát được và cách sửa đề xuất.',
        cover: 'work.sticky-plan',
        dueInDays: 1,
      ),
      PresetCard(
        titleEn: 'Prepare a short release checklist',
        titleVi: 'Soạn danh sách kiểm tra trước khi phát hành',
        column: 0,
        category: 3,
        dueInDays: 9,
      ),
      PresetCard(
        titleEn: 'Write a quick-start guide',
        titleVi: 'Viết hướng dẫn bắt đầu nhanh',
        column: 0,
        category: 2,
        noteEn:
            'Use one small example that someone can finish in five minutes.',
        noteVi: 'Dùng một ví dụ nhỏ có thể làm xong trong năm phút.',
        cover: 'study.open-book',
        dueInDays: 2,
      ),
      PresetCard(
        titleEn: 'Create a shared definition of done',
        titleVi: 'Thống nhất tiêu chí hoàn thành',
        column: 3,
        category: 0,
        subtasks: [
          ('Name the expected result', 'Nêu kết quả mong đợi'),
          ('Add the review step', 'Thêm bước kiểm tra'),
          ('Record how to hand it over', 'Ghi cách bàn giao'),
        ],
        done: 3,
      ),
      PresetCard(
        titleEn: 'Gather the project reference files',
        titleVi: 'Tập hợp tài liệu tham khảo của dự án',
        column: 3,
        category: 0,
        cover: 'work.folder-stack',
      ),
      PresetCard(
        titleEn: 'Park ideas for a later version',
        titleVi: 'Lưu ý tưởng cho phiên bản sau',
        column: 0,
        category: null,
        dueInDays: 4,
      ),
    ],
  ),
  TemplatePreset(
    id: 'study',
    type: 'study',
    nameEn: 'University term',
    nameVi: 'Học kỳ đại học',
    blurbEn:
        'Subjects, a weekly timetable, exams and assignments for one term.',
    blurbVi: 'Môn học, thời khoá biểu, lịch thi và bài tập trong một học kỳ.',
    pro: false,
    cover: 'study.notebook-grid',
    termWeeks: 15,
    columns: [('To Do', 'Cần làm'), ('Doing', 'Đang làm'), ('Done', 'Xong')],
    categories: [
      PresetCategory(
        nameEn: 'Web Programming',
        nameVi: 'Lập trình Web',
        hue: 0,
        code: 'WEB201',
        credits: 3,
      ),
      PresetCategory(
        nameEn: 'Databases',
        nameVi: 'Cơ sở dữ liệu',
        hue: 1,
        code: 'DB202',
        credits: 3,
      ),
      PresetCategory(
        nameEn: 'Computer Networks',
        nameVi: 'Mạng máy tính',
        hue: 2,
        code: 'NET203',
        credits: 3,
      ),
      PresetCategory(
        nameEn: 'English B2',
        nameVi: 'Tiếng Anh B2',
        hue: 4,
        code: 'ENG204',
        credits: 4,
      ),
    ],
    classes: [
      PresetClass(0, 1, 7 * 60, 9 * 60 + 30, 'P.301'),
      PresetClass(0, 4, 13 * 60 + 30, 15 * 60 + 30, 'Lab 2'),
      PresetClass(1, 2, 9 * 60 + 30, 11 * 60 + 30, 'P.204'),
      PresetClass(2, 3, 13 * 60 + 30, 16 * 60, 'P.105'),
      PresetClass(2, 5, 7 * 60 + 30, 9 * 60 + 30, 'Lab 1'),
      PresetClass(3, 2, 15 * 60, 17 * 60, 'P.402'),
    ],
    cards: [
      PresetCard(
        titleEn: 'Group project: bookshop website',
        titleVi: 'Bài tập lớn: web bán sách (nhóm 4 người)',
        column: 1,
        category: 0,
        subtasks: [
          ('Design the pages', 'Thiết kế giao diện'),
          ('Cart API', 'API giỏ hàng'),
          ('Test the checkout', 'Kiểm thử thanh toán'),
          ('Write the report', 'Viết báo cáo'),
        ],
        done: 1,
        cover: 'study.open-book',
        dueInDays: 12,
      ),
      PresetCard(
        titleEn: 'Lab 3: sign-up form with validation',
        titleVi: 'Lab 3: form đăng ký có kiểm tra dữ liệu',
        column: 0,
        category: 0,
        cover: 'study.pencil-case',
        subtasks: [
          ('HTML form', 'Form HTML'),
          ('Validate in JavaScript', 'Kiểm tra bằng JavaScript'),
          ('Submit on the course site', 'Nộp lên trang môn học'),
        ],
        dueInDays: 3,
      ),
      PresetCard(
        titleEn: 'Draw the ERD for the library topic',
        titleVi: 'Vẽ ERD cho đề tài quản lý thư viện',
        column: 0,
        category: 1,
        cover: 'study.notebook-grid',
        dueInDays: 6,
      ),
      PresetCard(
        titleEn: 'Databases midterm',
        titleVi: 'Thi giữa kỳ Cơ sở dữ liệu',
        column: 0,
        category: 1,
        subtasks: [
          ('Normal forms', 'Ôn chuẩn hoá'),
          ('SQL joins', 'Luyện SQL JOIN'),
          ('Last year paper', 'Làm đề năm trước'),
        ],
        exam: PresetExam(9, 8 * 60, 'P.204'),
      ),
      PresetCard(
        titleEn: 'Wireshark lab: read a TCP handshake',
        titleVi: 'Lab Wireshark: phân tích bắt tay TCP',
        column: 1,
        category: 2,
        subtasks: [
          ('Capture traffic', 'Bắt gói tin'),
          ('Mark the three steps', 'Đánh dấu ba bước'),
        ],
        done: 1,
        dueInDays: 4,
      ),
      PresetCard(
        titleEn: 'Group report: an office network',
        titleVi: 'Báo cáo nhóm: mô hình mạng doanh nghiệp',
        column: 0,
        category: 2,
        subtasks: [
          ('Split the work', 'Chia việc trong nhóm'),
          ('Draw the topology', 'Vẽ sơ đồ mạng'),
          ('Write it up', 'Viết báo cáo'),
        ],
        dueInDays: 15,
      ),
      PresetCard(
        titleEn: 'Essay, 250 words: technology in class',
        titleVi: 'Essay 250 từ: công nghệ trong lớp học',
        column: 0,
        category: 3,
        dueInDays: 2,
      ),
      PresetCard(
        titleEn: 'English speaking midterm',
        titleVi: 'Thi nói giữa kỳ Tiếng Anh',
        column: 0,
        category: 3,
        exam: PresetExam(6, 14 * 60, 'P.402'),
      ),
      PresetCard(
        titleEn: 'Hand in lab 2: CSS flexbox',
        titleVi: 'Nộp lab 2: CSS Flexbox',
        column: 2,
        category: 0,
      ),
      PresetCard(
        titleEn: 'Computer Networks final',
        titleVi: 'Thi cuối kỳ Mạng máy tính',
        column: 0,
        category: 2,
        exam: PresetExam(40, 7 * 60 + 30, 'Hội trường A'),
      ),
    ],
  ),
  TemplatePreset(
    id: 'shopping',
    type: 'shopping',
    nameEn: 'New room shopping',
    nameVi: 'Sắm đồ phòng trọ mới',
    blurbEn: 'Products with prices, a budget, and what is left to spend.',
    blurbVi: 'Món cần mua có giá, ngân sách và số tiền còn lại.',
    pro: true,
    cover: 'shopping.market-tote',
    budget: 5000000,
    columns: [
      ('Want', 'Muốn mua'),
      ('Thinking it over', 'Đang cân nhắc'),
      ('Ordered', 'Đã đặt mua'),
      ('Received', 'Đã nhận'),
    ],
    stages: ['want', 'want', 'ordered', 'received'],
    categories: [
      PresetCategory(nameEn: 'Kitchen', nameVi: 'Nhà bếp', hue: 1),
      PresetCategory(nameEn: 'Bedroom', nameVi: 'Phòng ngủ', hue: 4),
      PresetCategory(nameEn: 'Study corner', nameVi: 'Góc học tập', hue: 0),
      PresetCategory(nameEn: 'Everyday', nameVi: 'Đồ dùng hằng ngày', hue: 2),
    ],
    cards: [
      PresetCard(
        titleEn: 'Rice cooker 1.2 L',
        titleVi: 'Nồi cơm điện 1,2 L',
        column: 1,
        category: 0,
        subtasks: [
          ('Compare two models', 'So sánh hai mẫu'),
          ('Ask about the warranty', 'Hỏi thời gian bảo hành'),
        ],
        done: 1,
        cover: 'shopping.pantry-jars',
        dueInDays: 7,
        product: PresetProduct(890000, store: 'Điện máy gần nhà'),
      ),
      PresetCard(
        titleEn: 'Two non-stick pans',
        titleVi: 'Bộ 2 chảo chống dính',
        column: 2,
        category: 0,
        cover: 'shopping.ceramic-picks',
        product: PresetProduct(450000, store: 'Shop online'),
      ),
      PresetCard(
        titleEn: 'Bedding set',
        titleVi: 'Bộ chăn ga gối',
        column: 3,
        category: 1,
        subtasks: [('Wash before use', 'Giặt trước khi dùng')],
        done: 1,
        cover: 'shopping.fabric-swatches',
        product: PresetProduct(620000),
      ),
      PresetCard(
        titleEn: 'LED desk lamp',
        titleVi: 'Đèn bàn học LED',
        column: 1,
        category: 2,
        dueInDays: 5,
        product: PresetProduct(350000),
        subtasks: [
          ('Warm light', 'Có ánh sáng ấm'),
          ('USB-C power', 'Cấp nguồn USB-C'),
        ],
      ),
      PresetCard(
        titleEn: 'Desk chair',
        titleVi: 'Ghế ngồi học',
        column: 0,
        category: 2,
        noteEn: 'Try one in a shop before buying.',
        noteVi: 'Ra cửa hàng ngồi thử trước khi mua.',
        product: PresetProduct(null),
      ),
      PresetCard(
        titleEn: 'Laundry liquid 3.6 kg',
        titleVi: 'Nước giặt 3,6 kg',
        column: 0,
        category: 3,
        product: PresetProduct(189000, size: 3.6, unit: 'kg'),
      ),
      PresetCard(
        titleEn: 'Laundry liquid 2.4 kg',
        titleVi: 'Nước giặt 2,4 kg',
        column: 0,
        category: 3,
        product: PresetProduct(139000, size: 2.4, unit: 'kg'),
      ),
      PresetCard(
        titleEn: 'Four-shelf bookcase',
        titleVi: 'Giá sách 4 tầng',
        column: 0,
        category: 2,
        subtasks: [
          ('Measure the wall', 'Đo chỗ đặt'),
          ('Pick the wood colour', 'Chọn màu gỗ'),
        ],
        cover: 'shopping.wish-shelf',
        product: PresetProduct(520000),
      ),
    ],
  ),
  TemplatePreset(
    id: 'content',
    type: 'content',
    nameEn: 'Publishing pipeline',
    nameVi: 'Kênh nội dung tháng này',
    blurbEn: 'Ideas to published posts, with a schedule and what went out.',
    blurbVi: 'Từ ý tưởng tới bài đã đăng, có lịch đăng và lịch sử đăng.',
    pro: true,
    cover: 'creative.printing-blocks',
    columns: [
      ('Ideas', 'Ý tưởng'),
      ('In production', 'Đang sản xuất'),
      ('Ready to post', 'Sẵn sàng đăng'),
      ('Published', 'Đã đăng'),
    ],
    stages: ['idea', 'making', 'ready', 'published'],
    categories: [
      PresetCategory(nameEn: 'Tips', nameVi: 'Mẹo thực tế', hue: 0),
      PresetCategory(nameEn: 'Stories', nameVi: 'Câu chuyện', hue: 1),
      PresetCategory(nameEn: 'Behind the scenes', nameVi: 'Hậu trường', hue: 2),
    ],
    cards: [
      PresetCard(
        titleEn: '30-second video: three morning English habits',
        titleVi: 'Video 30 giây: 3 thói quen học tiếng Anh buổi sáng',
        column: 1,
        category: 0,
        subtasks: [
          ('Script', 'Kịch bản'),
          ('Shoot', 'Quay'),
          ('Edit', 'Dựng'),
          ('Subtitles', 'Phụ đề'),
        ],
        done: 1,
        cover: 'creative.paint-palette',
        dueInDays: 1,
        post: PresetPost(
          'video',
          ['tiktok', 'youtube'],
          inDays: 2,
          minute: 19 * 60,
        ),
      ),
      PresetCard(
        titleEn: 'Photo: my desk in the morning',
        titleVi: 'Ảnh: góc làm việc buổi sáng',
        column: 2,
        category: 2,
        cover: 'creative.paper-collage',
        post: PresetPost('image', ['instagram'], inDays: 1, minute: 8 * 60),
      ),
      PresetCard(
        titleEn: 'Post: how I plan my week',
        titleVi: 'Bài viết: cách mình lên kế hoạch tuần',
        column: 0,
        category: 1,
        post: PresetPost('post', ['facebook']),
      ),
      PresetCard(
        titleEn: 'Story: ask what to make next',
        titleVi: 'Story: hỏi người xem chủ đề tiếp theo',
        column: 0,
        category: 1,
        subtasks: [
          ('Write three options', 'Viết ba lựa chọn'),
          ('Add a poll sticker', 'Gắn sticker bình chọn'),
        ],
        post: PresetPost('story', ['instagram']),
      ),
      PresetCard(
        titleEn: 'Behind the scenes of last week shoot',
        titleVi: 'Hậu trường buổi quay tuần trước',
        column: 3,
        category: 2,
        post: PresetPost('video', ['tiktok'], publishedDaysAgo: 3),
      ),
      PresetCard(
        titleEn: 'Carousel: five free study apps',
        titleVi: 'Carousel: 5 app học miễn phí',
        column: 1,
        category: 0,
        subtasks: [
          ('Pick the apps', 'Chọn app'),
          ('Make the slides', 'Làm 5 trang ảnh'),
          ('Write the caption', 'Viết chú thích'),
        ],
        done: 2,
        dueInDays: 3,
        post: PresetPost('image', ['instagram'], inDays: 4, minute: 12 * 60),
      ),
      PresetCard(
        titleEn: 'Video: a book I read this month',
        titleVi: 'Video: review cuốn sách đọc trong tháng',
        column: 0,
        category: 1,
        subtasks: [
          ('Note three ideas', 'Ghi ba ý chính'),
          ('Find a quiet spot to film', 'Tìm chỗ quay yên tĩnh'),
        ],
        post: PresetPost('video', ['youtube']),
      ),
      PresetCard(
        titleEn: 'Video: a day at school',
        titleVi: 'Video: một ngày đi học',
        column: 3,
        category: 1,
        cover: 'events.stage-curtain',
        post: PresetPost('video', ['tiktok'], publishedDaysAgo: 6),
      ),
    ],
  ),
];

TemplatePreset? presetById(String id) {
  for (final preset in templatePresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
