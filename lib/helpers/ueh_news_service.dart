import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Một bài viết trong danh sách (trang chủ tin tức hoặc trang chuyên mục).
class NewsSummary {
  const NewsSummary({
    required this.title,
    required this.url,
    this.imageUrl = '',
    this.category = '',
    this.date = '',
    this.sdgIcons = const [],
  });

  final String title;
  final String url;
  final String imageUrl;
  final String category;

  /// Ngày đăng, vd "27 tháng 09 năm 2026"; rỗng nếu không lấy được.
  final String date;
  final List<String> sdgIcons;
}

/// Dữ liệu trang https://ueh.edu.vn/tintucmobile (tab Tin tức ở Trang chủ).
class NewsHome {
  const NewsHome({required this.featured, required this.items});

  final NewsSummary? featured;
  final List<NewsSummary> items;
}

/// Một trang của danh sách chuyên mục, vd .../tin-tuc/page/2/
class NewsListPage {
  const NewsListPage({
    required this.items,
    required this.lastPage,
    required this.pageBaseUrl,
  });

  final List<NewsSummary> items;
  final int lastPage;

  /// Gốc URL của các trang sau, lấy từ thanh phân trang. Có chuyên mục khác
  /// với URL trang 1, vd /cuoc-song-ueh/ phân trang là /cuoc-song-ueh/tin-tuc/page/2/
  final String pageBaseUrl;
}

class NewsDetail {
  const NewsDetail({
    required this.title,
    required this.date,
    required this.sdgIcons,
    required this.contentHtml,
    this.redirectUrl = '',
  });

  final String title;
  final String date;
  final List<String> sdgIcons;
  final String contentHtml;

  /// Một số bài không có nội dung trên ueh.edu.vn mà chỉ chuyển hướng
  /// (meta refresh) sang trang khác, vd ueh50.ueh.edu.vn.
  final String redirectUrl;
}

class UehNewsService {
  UehNewsService._();

  static const homeUrl = 'https://ueh.edu.vn/tintucmobile';

  /// Nguồn bài viết khi bấm chữ danh mục hoặc nút "Xem thêm" ở trang Tin tức.
  static const cuocSongUehUrl = 'https://ueh.edu.vn/cuoc-song-ueh/';

  static Future<Document> _fetch(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: const {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} khi tải $url');
    }
    return html_parser.parse(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  /// Link trên web UEH có thể chứa [ ], dấu gạch dài, khoảng trắng hay cả
  /// ký tự xuống dòng; Uri.resolve sẽ mã hoá lại cho hợp lệ.
  static String _absolute(String? href, {bool dropQuery = false}) {
    if (href == null) return '';
    final cleaned = href.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
    if (cleaned.isEmpty || cleaned == '#') return '';
    final uri = Uri.parse('https://ueh.edu.vn/').resolve(cleaned);
    return (dropQuery ? uri.replace(query: '') : uri).toString().replaceAll(
      RegExp(r'\?$'),
      '',
    );
  }

  static String _text(Element? e) =>
      (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<String> _sdgIcons(Element? root) =>
      (root?.querySelectorAll('ul.sdg-featured-news img.category-icon') ??
              const <Element>[])
          .map((img) => _absolute(img.attributes['src']))
          .where((src) => src.isNotEmpty)
          .toList();

  /// Trang 1 là [baseUrl], trang n là [baseUrl]/page/n/
  static String pageUrl(String baseUrl, int page) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return page <= 1 ? base : '${base}page/$page/';
  }

  static Future<NewsHome> fetchHome() async {
    final doc = await _fetch(homeUrl);
    NewsSummary? featured;
    final items = <NewsSummary>[];

    for (final article in doc.querySelectorAll('.grid-container article')) {
      final featuredTitle = article.querySelector('p.title-lastes');
      if (featuredTitle != null) {
        final link = featuredTitle.nextElementSibling?.querySelector('a');
        featured = NewsSummary(
          title: _text(link),
          url: _absolute(link?.attributes['href'], dropQuery: true),
          imageUrl: _absolute(article.querySelector('img')?.attributes['src']),
          category: _text(featuredTitle),
        );
        continue;
      }

      final headings = article.querySelectorAll('.content h3');
      if (headings.length < 2) continue;
      final link = headings[1].querySelector('a');
      items.add(
        NewsSummary(
          title: _text(link),
          url: _absolute(link?.attributes['href'], dropQuery: true),
          imageUrl: _absolute(article.querySelector('img')?.attributes['src']),
          category: _text(headings[0]),
        ),
      );
    }

    return NewsHome(featured: featured, items: items);
  }

  static Future<NewsListPage> fetchListPage(String baseUrl, int page) async {
    final doc = await _fetch(pageUrl(baseUrl, page));

    final entries = [
      for (final article in doc.querySelectorAll('article.list-item'))
        (
          article: article,
          link: article.querySelector('a.news-title-view'),
          url: _absolute(
            article.querySelector('a.news-title-view')?.attributes['href'],
          ),
        ),
    ].where((e) => e.url.isNotEmpty).toList();

    // Trang danh sách không có ngày đăng, ngày chỉ nằm trong trang chi tiết
    // (thẻ <p> ngay dưới #title), nên tải song song trang của từng bài.
    final dates = await Future.wait(entries.map((e) => _fetchDate(e.url)));

    final items = <NewsSummary>[
      for (var i = 0; i < entries.length; i++)
        NewsSummary(
          title: _text(entries[i].link),
          url: entries[i].url,
          imageUrl: _absolute(
            entries[i].article
                .querySelector('.card-photo img')
                ?.attributes['src'],
          ),
          date: dates[i],
          sdgIcons: _sdgIcons(entries[i].article),
        ),
    ];

    // Số trang cuối lấy từ link lớn nhất trong thanh phân trang ("Tới cuối").
    var lastPage = page;
    var pageBaseUrl = '';
    for (final a in doc.querySelectorAll('.pagination a.page-link')) {
      final match = RegExp(r'^(.*/)page/(\d+)')
          .firstMatch(a.attributes['href'] ?? '');
      if (match == null) continue;
      if (pageBaseUrl.isEmpty) pageBaseUrl = _absolute(match.group(1));
      final n = int.parse(match.group(2)!);
      if (n > lastPage) lastPage = n;
    }

    return NewsListPage(
      items: items,
      lastPage: lastPage,
      pageBaseUrl: pageBaseUrl,
    );
  }

  /// Ngày đăng trong trang chi tiết: thẻ <p> ngay dưới tiêu đề #title.
  static String _dateOf(Document doc) {
    final el = doc.querySelector('#title')?.nextElementSibling;
    return el?.localName == 'p' ? _text(el) : '';
  }

  static Future<String> _fetchDate(String url) async {
    try {
      return _dateOf(await _fetch(url));
    } catch (_) {
      return '';
    }
  }

  static Future<NewsDetail> fetchDetail(String url) async {
    final doc = await _fetch(url);
    final titleEl = doc.querySelector('#title');
    final column = titleEl?.parent;

    final content = doc.querySelector('#news_content');
    final refresh = content?.querySelector('meta[http-equiv="Refresh"]');
    final redirect = RegExp(
      r"url='?([^']+)'?",
      caseSensitive: false,
    ).firstMatch(refresh?.attributes['content'] ?? '');
    refresh?.remove();
    content?.querySelector('#share_facebook')?.remove();
    for (final img in content?.querySelectorAll('img') ?? const <Element>[]) {
      img.attributes['src'] = _absolute(img.attributes['src']);
    }
    for (final a in content?.querySelectorAll('a') ?? const <Element>[]) {
      a.attributes['href'] = _absolute(a.attributes['href']);
    }

    return NewsDetail(
      title: _text(titleEl),
      date: _dateOf(doc),
      sdgIcons: _sdgIcons(column),
      contentHtml: content?.innerHtml ?? '',
      redirectUrl: _absolute(redirect?.group(1)),
    );
  }
}
