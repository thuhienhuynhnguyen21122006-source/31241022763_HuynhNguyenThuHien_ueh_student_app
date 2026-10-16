import 'dart:convert';

import 'package:http/http.dart' as http;

import 'student_api.dart';

/// Một tin trong danh sách; [content] chỉ có khi lấy chi tiết.
class NewsItem {
  const NewsItem({
    required this.uid,
    required this.catUid,
    required this.categoryName,
    required this.title,
    this.shortDesc = '',
    this.postDate,
    this.sdgs = const [],
    this.isFeatured = false,
    this.backgroundImg,
    this.thumbnailImg,
    this.content = '',
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    uid: (json['uid'] as num?)?.toInt() ?? 0,
    catUid: (json['cat_uid'] as num?)?.toInt() ?? 0,
    // Dữ liệu có thể dính \r\n ở cuối.
    categoryName: json['category_name']?.toString().trim() ?? '',
    title: json['title']?.toString().trim() ?? '',
    shortDesc: json['short_desc']?.toString().trim() ?? '',
    postDate: DateTime.tryParse(json['post_date']?.toString() ?? ''),
    sdgs: [
      for (final n in json['sdgs'] as List? ?? const [])
        if (n is num && n >= 1 && n <= 17) n.toInt(),
    ],
    isFeatured: json['is_featured'] == true,
    backgroundImg: _url(json['background_img']),
    thumbnailImg: _url(json['thumbnail_img']),
    content: json['content']?.toString() ?? '',
  );

  static String? _url(Object? value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  final int uid;
  final int catUid;
  final String categoryName;
  final String title;
  final String shortDesc;
  final DateTime? postDate;

  /// Uid SDG từ 1 đến 17, xem [NewsApi.sdgIconUrl].
  final List<int> sdgs;
  final bool isFeatured;

  /// URL đầy đủ; null nếu tin không có ảnh.
  final String? backgroundImg;
  final String? thumbnailImg;

  /// HTML của bài viết.
  final String content;

  /// Ngày đăng dạng dd/MM/yyyy; rỗng nếu không có.
  String get postDateText {
    final d = postDate;
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

/// Một trang của GET /api/news?cat_uid=...
class NewsPage {
  const NewsPage({required this.total, required this.items});

  final int total;
  final List<NewsItem> items;
}

/// Tin tức từ API UEH Student (mục 6 API_GUIDE). Không cần token.
class NewsApi {
  NewsApi._();

  static const _timeout = Duration(seconds: 20);
  static const pageSize = 20;

  /// Mục "Cuộc sống UEH", mở khi bấm "Xem thêm" ở trang Tin tức.
  static const cuocSongUehCatUid = 219;

  /// Icon SDG app đang dùng (cùng bộ ảnh trên ueh.edu.vn), [n] từ 1 đến 17.
  static String sdgIconUrl(int n) =>
      'https://ueh.edu.vn/images/sdg/vi/sdg-$n.png';

  static Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('${StudentApi.baseUrl}$path')
        .replace(queryParameters: query);
    final res = await http.get(uri).timeout(_timeout);
    Object? data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      // Body rỗng hoặc không phải JSON.
    }
    if (res.statusCode != 200) {
      final message = data is Map ? data['message'] : null;
      throw ApiException(
        res.statusCode,
        message is String && message.isNotEmpty
            ? message
            : 'Có lỗi xảy ra (HTTP ${res.statusCode}).',
      );
    }
    return data;
  }

  /// Tối đa 5 tin: tin nổi bật trước, sau đó tin mới nhất của mục 219-222.
  static Future<List<NewsItem>> fetchFeatured() async {
    final data = await _get('/api/news/featured');
    return [
      for (final e in data as List? ?? const [])
        if (e is Map<String, dynamic>) NewsItem.fromJson(e),
    ];
  }

  static Future<NewsPage> fetchByCategory(
    int catUid, {
    int offset = 0,
    int limit = pageSize,
  }) async {
    final data = await _get('/api/news', {
      'cat_uid': '$catUid',
      'limit': '$limit',
      'offset': '$offset',
    });
    final map = data is Map<String, dynamic> ? data : const {};
    return NewsPage(
      total: (map['total'] as num?)?.toInt() ?? 0,
      items: [
        for (final e in map['items'] as List? ?? const [])
          if (e is Map<String, dynamic>) NewsItem.fromJson(e),
      ],
    );
  }

  static Future<NewsItem> fetchDetail(int uid) async =>
      NewsItem.fromJson(await _get('/api/news/$uid') as Map<String, dynamic>);
}
