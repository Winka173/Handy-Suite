part of '../handy_boards_engine.dart';

/// A field a template suggests for its cards. The Smart Setup lists them,
/// each ticked, and the board starts with the ones kept. Fields that come
/// with a template are free to fill; making one's own fields is Pro.
class TemplateCardField {
  final L10n name;
  final String type; // one of [fieldTypes]
  final List<L10n> options;

  /// Shown on the card front, not only inside the card.
  final bool onCard;
  const TemplateCardField(
    this.name,
    this.type, {
    this.options = const [],
    this.onCard = false,
  });
}

/// In [TemplateAnswers]: the indices of the suggested fields kept (all by
/// default).
const cardFieldsKey = '_cardFields';

/// The fields [templateId] suggests, in order.
List<TemplateCardField> templateCardFields(String templateId) =>
    _cardFields[templateId] ?? const [];

const _cost = TemplateCardField(
  L10n('Cost', 'Chi phí'),
  'number',
  onCard: true,
);
const _link = TemplateCardField(L10n('Link', 'Link'), 'url');
const _owner = TemplateCardField(
  L10n('Owner', 'Người làm'),
  'text',
  onCard: true,
);
const _place = TemplateCardField(L10n('Place', 'Địa điểm'), 'text');

const _cardFields = <String, List<TemplateCardField>>{
  'semester': [TemplateCardField(L10n('Grade', 'Điểm'), 'number')],
  'group-assignment': [
    _owner,
    TemplateCardField(L10n('Shared doc', 'Link tài liệu'), 'url'),
  ],
  'exam-revision': [
    TemplateCardField(
      L10n('Confidence', 'Mức tự tin'),
      'single',
      options: [
        L10n('Low', 'Thấp'),
        L10n('Medium', 'Vừa'),
        L10n('High', 'Cao'),
      ],
      onCard: true,
    ),
  ],
  'course': [TemplateCardField(L10n('Lesson link', 'Link bài học'), 'url')],
  'thesis': [
    TemplateCardField(L10n('Words', 'Số chữ'), 'number', onCard: true),
    TemplateCardField(L10n('Source', 'Nguồn tài liệu'), 'url'),
  ],
  'project': [_owner, _link],
  'sprint': [
    TemplateCardField(L10n('Points', 'Điểm story'), 'number', onCard: true),
    _owner,
  ],
  'launch': [_owner, _link],
  'meeting': [TemplateCardField(L10n('Led by', 'Người chủ trì'), 'text')],
  'shopping': [
    TemplateCardField(L10n('Price', 'Giá'), 'number', onCard: true),
    TemplateCardField(L10n('Where to buy', 'Link mua'), 'url'),
  ],
  'home-improvement': [
    _cost,
    TemplateCardField(L10n('Shop or worker', 'Cửa hàng / thợ'), 'text'),
  ],
  'event': [
    _cost,
    _place,
    TemplateCardField(L10n('Paid', 'Đã thanh toán'), 'checkbox'),
  ],
  'content': [
    TemplateCardField(
      L10n('Channel', 'Kênh'),
      'single',
      options: [
        L10n('Facebook', 'Facebook'),
        L10n('TikTok', 'TikTok'),
        L10n('YouTube', 'YouTube'),
        L10n('Blog', 'Blog'),
      ],
      onCard: true,
    ),
    TemplateCardField(L10n('Publish on', 'Ngày đăng'), 'date'),
    _link,
  ],
  'photography': [
    _place,
    TemplateCardField(L10n('Client', 'Khách hàng'), 'text'),
  ],
  'inspiration': [_link],
  'writing': [
    TemplateCardField(L10n('Words', 'Số chữ'), 'number', onCard: true),
  ],
  'campaign': [
    TemplateCardField(L10n('Budget', 'Ngân sách'), 'number', onCard: true),
    TemplateCardField(
      L10n('Channel', 'Kênh'),
      'single',
      options: [
        L10n('Facebook', 'Facebook'),
        L10n('TikTok', 'TikTok'),
        L10n('Email', 'Email'),
        L10n('Ads', 'Quảng cáo'),
      ],
    ),
  ],
  'trip': [
    _cost,
    TemplateCardField(L10n('Booking link', 'Link đặt chỗ'), 'url'),
    TemplateCardField(L10n('Booked', 'Đã đặt'), 'checkbox', onCard: true),
    TemplateCardField(L10n('Address', 'Địa chỉ'), 'text'),
  ],
  'workshop': [
    TemplateCardField(L10n('Speaker', 'Người nói'), 'text', onCard: true),
    TemplateCardField(L10n('Room', 'Phòng'), 'text'),
  ],
  'moving': [_cost],
  'holiday': [_cost, TemplateCardField(L10n('Who buys', 'Người mua'), 'text')],
};
