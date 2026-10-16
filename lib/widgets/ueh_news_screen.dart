import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/news_api.dart';
import '../helpers/student_api.dart';

const uehOrange = Color(0xFFF26F21);
const _teal = Color(0xFF0B5D66);

/// Link trong nội dung bài viết mở bằng trình duyệt ngoài (API chỉ tra được
/// tin theo uid, không theo URL ueh.edu.vn).
void _openLink(String? url) {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ---------------------------------------------------------------------------
// Tab "Tin tức" ở Trang chủ — dữ liệu từ GET /api/news/featured
// ---------------------------------------------------------------------------

class UehNewsTab extends StatefulWidget {
  const UehNewsTab({super.key});

  @override
  State<UehNewsTab> createState() => _UehNewsTabState();
}

class _UehNewsTabState extends State<UehNewsTab> {
  late Future<List<NewsItem>> _future = NewsApi.fetchFeatured();

  Future<void> _reload() async {
    final future = NewsApi.fetchFeatured();
    setState(() {
      _future = future;
    });
    await future.catchError((_) => const <NewsItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<NewsItem>>(
          future: _future,
          builder: (context, snapshot) {
            // Phần tử đầu là tin nổi bật, các tin sau là tin mới nhất theo mục.
            final news = snapshot.data ?? const <NewsItem>[];
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
                  if (news.isNotEmpty) _FeaturedNews(item: news.first),
                  for (final item in news.skip(1)) ...[
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
                          catUid: NewsApi.cuocSongUehCatUid,
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

  final NewsItem item;

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
          onTap: () => UehNewsDetailScreen.open(context, item.uid),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight = constraints.maxWidth * 9 / 16;
              final fallback = Image.asset(
                'asset/image/ueh-background.jpg',
                width: double.infinity,
                height: imageHeight,
                fit: BoxFit.cover,
              );
              final imageUrl = item.backgroundImg;

              return Stack(
                children: [
                  // Lớp dưới: ảnh 16:9, quyết định kích thước của Stack.
                  if (imageUrl == null)
                    fallback
                  else
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
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

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: () => UehNewsDetailScreen.open(context, item.uid),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bấm chữ danh mục -> danh sách tin của mục đó; bấm phần còn lại
            // của thẻ -> mở bài.
            InkWell(
              onTap: () => UehNewsScreen.open(
                context,
                title: item.categoryName,
                catUid: item.catUid,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item.categoryName.toUpperCase(),
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
// Danh sách tin của một mục (GET /api/news?cat_uid=...), lazy load
// ---------------------------------------------------------------------------

class UehNewsScreen extends StatefulWidget {
  const UehNewsScreen({super.key, required this.title, required this.catUid});

  final String title;
  final int catUid;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required int catUid,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UehNewsScreen(title: title, catUid: catUid),
      ),
    );
  }

  @override
  State<UehNewsScreen> createState() => _UehNewsScreenState();
}

class _UehNewsScreenState extends State<UehNewsScreen> {
  final _scrollController = ScrollController();
  final _items = <NewsItem>[];

  /// Số tin server đã trả, dùng làm offset cho lần tải sau.
  int _offset = 0;
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
      final page = await NewsApi.fetchByCategory(
        widget.catUid,
        offset: _offset,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        // Có tin mới đăng thì tin cũ bị đẩy sang trang sau, bỏ tin trùng.
        final seen = _items.map((e) => e.uid).toSet();
        _items.addAll(page.items.where((e) => seen.add(e.uid)));
        _offset += page.items.length;
        _hasMore = page.items.isNotEmpty && _offset < page.total;
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
      _offset = 0;
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
        _items.isEmpty ? 'Chưa có bài viết' : 'Đã hết bài viết',
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

  final NewsItem item;
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
            onTap: () => UehNewsDetailScreen.open(context, item.uid),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: item.thumbnailImg == null
                        ? const _NoThumbnail()
                        : Image.network(
                            item.thumbnailImg!,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _NoThumbnail(),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.postDateText.isNotEmpty) ...[
                          Text(
                            item.postDateText,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (item.sdgs.isNotEmpty) ...[
                          _SdgIcons(sdgs: item.sdgs, size: 22),
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
// Chi tiết tin (GET /api/news/{uid}), nội dung dựng bằng flutter_html
// ---------------------------------------------------------------------------

class UehNewsDetailScreen extends StatefulWidget {
  const UehNewsDetailScreen({super.key, required this.uid});

  final int uid;

  static Future<void> open(BuildContext context, int uid) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => UehNewsDetailScreen(uid: uid)));
  }

  @override
  State<UehNewsDetailScreen> createState() => _UehNewsDetailScreenState();
}

class _UehNewsDetailScreenState extends State<UehNewsDetailScreen> {
  // Chỉ tải nội dung khi mở bài.
  late Future<NewsItem> _future = NewsApi.fetchDetail(widget.uid);

  Future<void> _reload() async {
    final future = NewsApi.fetchDetail(widget.uid);
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
        child: FutureBuilder<NewsItem>(
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
                if (d.postDateText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    d.postDateText,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
                if (d.sdgs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SdgIcons(sdgs: d.sdgs, size: 36),
                ],
                const SizedBox(height: 12),
                Html(
                  data: d.content,
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
                          // Ảnh trong bài là link ueh.edu.vn; phòng khi gặp
                          // đường dẫn tương đối.
                          Uri.parse('https://ueh.edu.vn/')
                              .resolve(ext.attributes['src'] ?? '')
                              .toString(),
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  onLinkTap: (url, _, _) => _openLink(url),
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
  const _SdgIcons({required this.sdgs, required this.size});

  /// Uid SDG từ 1 đến 17.
  final List<int> sdgs;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final n in sdgs)
          Image.network(
            NewsApi.sdgIconUrl(n),
            width: size,
            height: size,
            errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
          ),
      ],
    );
  }
}

/// Ảnh thay thế khi tin không có thumbnail_img.
class _NoThumbnail extends StatelessWidget {
  const _NoThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported_outlined),
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
            'Không tải được dữ liệu.\n${apiErrorMessage(error ?? '')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
