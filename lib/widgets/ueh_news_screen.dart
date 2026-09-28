import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/ueh_news_service.dart';

const uehOrange = Color(0xFFF26F21);
const _teal = Color(0xFF0B5D66);

/// Link tới một bài viết trên ueh.edu.vn thì mở trong app,
/// còn lại (YouTube, Facebook...) mở bằng trình duyệt ngoài.
void _openLink(BuildContext context, String? url) {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final isUehArticle =
      uri.host.endsWith('ueh.edu.vn') &&
      uri.pathSegments.length >= 2 &&
      RegExp(r'-\d+$').hasMatch(uri.path);
  if (isUehArticle) {
    UehNewsDetailScreen.open(context, url);
  } else {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Web ghi danh mục bằng chữ in hoa ("KHOA HỌC - GÓC NHÌN CHUYÊN GIA");
/// đổi về dạng tên như trên breadcrumb của web ("Khoa học - Góc nhìn chuyên gia").
String _categoryTitle(String category) {
  final lower = category.toLowerCase().replaceAll('ueh', 'UEH');
  return lower.replaceAllMapped(
    RegExp(r'(^|[-&]\s*)(\S)'),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );
}

// ---------------------------------------------------------------------------
// Tab "Tin tức" ở Trang chủ — dữ liệu từ https://ueh.edu.vn/tintucmobile
// ---------------------------------------------------------------------------

class UehNewsTab extends StatefulWidget {
  const UehNewsTab({super.key});

  @override
  State<UehNewsTab> createState() => _UehNewsTabState();
}

class _UehNewsTabState extends State<UehNewsTab> {
  late Future<NewsHome> _future = UehNewsService.fetchHome();

  Future<void> _reload() async {
    final future = UehNewsService.fetchHome();
    setState(() {
      _future = future;
    });
    await future.catchError((_) => const NewsHome(featured: null, items: []));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<NewsHome>(
          future: _future,
          builder: (context, snapshot) {
            final home = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                const Text(
                  'Tin tức',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: uehOrange,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thông tin mới nhất và kiến thức hữu ích từ UEH',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 24),
                if (snapshot.connectionState != ConnectionState.done)
                  const _Loading()
                else if (snapshot.hasError)
                  _ErrorBox(error: snapshot.error, onRetry: _reload)
                else ...[
                  if (home!.featured != null)
                    _FeaturedNews(item: home.featured!),
                  for (final item in home.items) ...[
                    const SizedBox(height: 20),
                    _CategoryNewsCard(item: item),
                  ],
                  const SizedBox(height: 32),
                  Center(
                    child: Material(
                      color: const Color(0xFFE8E8E8),
                      child: InkWell(
                        onTap: () => UehNewsScreen.open(
                          context,
                          title: 'Tin tức nổi bật',
                          url: UehNewsService.cuocSongUehUrl,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 10,
                          ),
                          child: Text(
                            'Xem thêm',
                            style: TextStyle(color: uehOrange, fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeaturedNews extends StatelessWidget {
  const _FeaturedNews({required this.item});

  final NewsSummary item;

  static const _radius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    // Cùng độ đổ bóng với _CardShell (elevation 3) nhưng bo góc 8, để bóng
    // khớp với ảnh đã bo góc.
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: _radius,
      child: ClipRRect(
        borderRadius: _radius,
        child: InkWell(
          onTap: () => _openLink(context, item.url),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight = constraints.maxWidth * 9 / 16;

              return Stack(
                children: [
                  // Lớp dưới: ảnh 16:9, quyết định kích thước của Stack.
                  Image.network(
                    item.imageUrl,
                    width: double.infinity,
                    height: imageHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Image.asset(
                      'asset/image/ueh-background.jpg',
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Lớp trên: gradient trong suốt -> đen ghim ở đáy ảnh; phần
                  // đệm trên 40 cho gradient mờ dần, phủ khoảng nửa dưới ảnh.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 40, 14, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              color: uehOrange,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'TIN NỔI BẬT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryNewsCard extends StatelessWidget {
  const _CategoryNewsCard({required this.item});

  final NewsSummary item;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: () => _openLink(context, item.url),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bấm chữ danh mục -> danh sách bài Cuộc sống UEH, nhưng tiêu đề
            // là tên danh mục vừa bấm; bấm phần còn lại của thẻ -> mở bài.
            InkWell(
              onTap: () => UehNewsScreen.open(
                context,
                title: _categoryTitle(item.category),
                url: UehNewsService.cuocSongUehUrl,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item.category.toUpperCase(),
                  style: const TextStyle(
                    color: uehOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Danh sách bài viết của một chuyên mục (vd Cuộc sống UEH), lazy load
// ---------------------------------------------------------------------------

class UehNewsScreen extends StatefulWidget {
  const UehNewsScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UehNewsScreen(title: title, url: url),
      ),
    );
  }

  @override
  State<UehNewsScreen> createState() => _UehNewsScreenState();
}

class _UehNewsScreenState extends State<UehNewsScreen> {
  final _scrollController = ScrollController();
  final _items = <NewsSummary>[];

  late String _pageBaseUrl = widget.url;
  int _nextPage = 1;
  int? _lastPage;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;
  // Tăng mỗi lần tải lại, để bỏ kết quả của lần tải cũ còn đang chạy.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await UehNewsService.fetchListPage(_pageBaseUrl, _nextPage);
      if (!mounted || generation != _generation) return;
      setState(() {
        // Có bài mới đăng thì các bài bị đẩy sang trang sau, bỏ bài trùng.
        final seen = _items.map((e) => e.url).toSet();
        _items.addAll(page.items.where((e) => seen.add(e.url)));
        _lastPage = page.lastPage;
        if (page.pageBaseUrl.isNotEmpty) _pageBaseUrl = page.pageBaseUrl;
        _hasMore = page.items.isNotEmpty && _nextPage < page.lastPage;
        _nextPage++;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _generation++;
      _items.clear();
      _pageBaseUrl = widget.url;
      _nextPage = 1;
      _lastPage = null;
      _hasMore = true;
      _isLoading = false;
    });
    await _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Chỉ có nút quay lại; tên danh mục hiện ở đầu danh sách.
      appBar: _newsAppBar(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _CategoryHeading(widget.title);
            }
            if (index <= _items.length) {
              return _ArticleRow(
                item: _items[index - 1],
                isFirst: index == 1,
                isLast: index == _items.length,
              );
            }
            return _buildFooter();
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_error != null) {
      return _ErrorBox(error: _error, onRetry: _loadNextPage);
    }
    if (_isLoading || _hasMore) {
      return const _Loading(small: true);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        _items.isEmpty
            ? 'Chưa có bài viết'
            : 'Đã hết bài viết (${_lastPage ?? 1} trang)',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

/// Một bài trong danh sách: Row [ảnh vuông | Column(ngày, SDG, tiêu đề)].
/// Các dòng ghép thành một khung chung: dòng đầu có viền trên, dòng cuối có
/// viền dưới, giữa các dòng là Divider.
class _ArticleRow extends StatelessWidget {
  const _ArticleRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final NewsSummary item;
  final bool isFirst;
  final bool isLast;

  static final _border = BorderSide(color: Colors.grey.shade300);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: isFirst ? 12 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: _border,
          right: _border,
          top: isFirst ? _border : BorderSide.none,
          bottom: isLast ? _border : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => UehNewsDetailScreen.open(context, item.url),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item.imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.date.isNotEmpty) ...[
                          Text(
                            item.date,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (item.sdgIcons.isNotEmpty) ...[
                          _SdgIcons(urls: item.sdgIcons, size: 22),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast) const Divider(height: 1, indent: 12, endIndent: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chi tiết bài viết, nội dung dựng bằng flutter_html
// ---------------------------------------------------------------------------

class UehNewsDetailScreen extends StatefulWidget {
  const UehNewsDetailScreen({super.key, required this.url});

  final String url;

  static Future<void> open(BuildContext context, String url) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => UehNewsDetailScreen(url: url)));
  }

  @override
  State<UehNewsDetailScreen> createState() => _UehNewsDetailScreenState();
}

class _UehNewsDetailScreenState extends State<UehNewsDetailScreen> {
  late Future<NewsDetail> _future = UehNewsService.fetchDetail(widget.url);

  Future<void> _reload() async {
    final future = UehNewsService.fetchDetail(widget.url);
    setState(() {
      _future = future;
    });
    await future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _newsAppBar(context),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<NewsDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _Loading();
            }
            if (snapshot.hasError) {
              return ListView(
                children: [_ErrorBox(error: snapshot.error, onRetry: _reload)],
              );
            }
            final d = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  d.title,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    color: uehOrange,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (d.date.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(d.date, style: const TextStyle(color: Colors.grey)),
                ],
                if (d.sdgIcons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SdgIcons(urls: d.sdgIcons, size: 36),
                ],
                if (d.redirectUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(d.redirectUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      'Đọc bài viết đầy đủ tại ${Uri.parse(d.redirectUrl).host}',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Html(
                  data: d.contentHtml,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(16),
                      lineHeight: const LineHeight(1.5),
                      textAlign: TextAlign.justify,
                    ),
                    'a': Style(color: _teal),
                  },
                  extensions: [
                    // Ảnh mặc định của flutter_html (BoxFit.fill trong dòng chữ)
                    // không hiện được ảnh của UEH, nên tự vẽ: rộng hết khung,
                    // giữ tỉ lệ.
                    TagExtension(
                      tagsToExtend: const {'img'},
                      builder: (ext) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Image.network(
                          ext.attributes['src'] ?? '',
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  onLinkTap: (url, _, _) => _openLink(context, url),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget dùng chung
// ---------------------------------------------------------------------------

/// AppBar của màn hình danh mục và bài viết: màu xanh UEH, chỉ có nút ←.
PreferredSizeWidget _newsAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: _teal,
    foregroundColor: Colors.white,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Quay lại',
      onPressed: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          context.go('/home');
        }
      },
    ),
  );
}

/// Tên danh mục màu cam, cùng cỡ với chữ "Tin tức" ở trang Tin tức.
class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: uehOrange,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SdgIcons extends StatelessWidget {
  const _SdgIcons({required this.urls, required this.size});

  final List<String> urls;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final url in urls)
          Image.network(
            url,
            width: size,
            height: size,
            errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
          ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(small ? 16 : 48),
      child: Center(
        child: SizedBox.square(
          dimension: small ? 24 : 36,
          child: CircularProgressIndicator(strokeWidth: small ? 2.5 : 4),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: Colors.grey, size: 40),
          const SizedBox(height: 8),
          Text(
            'Không tải được dữ liệu.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
