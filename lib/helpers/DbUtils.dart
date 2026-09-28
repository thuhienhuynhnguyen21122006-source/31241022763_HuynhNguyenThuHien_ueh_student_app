import 'package:sqflite/sqflite.dart';

class DrawerNavMenu {
  const DrawerNavMenu({
    required this.id,
    required this.iconCode,
    required this.menuName,
    required this.menuUrl,
    required this.ordering,
  });

  factory DrawerNavMenu.fromMap(Map<String, Object?> map) {
    return DrawerNavMenu(
      id: map['id'] as int,
      iconCode: map['icon_code'] as String? ?? '',
      menuName: map['menu_name'] as String? ?? '',
      menuUrl: map['menu_url'] as String? ?? '',
      ordering: map['ordering'] as int? ?? 0,
    );
  }

  final int id;
  final String iconCode;
  final String menuName;
  final String menuUrl;
  final int ordering;
}

class DbUtils {
  DbUtils._();

  static const _dbName = 'ueh_student.db';
  static const _dbVersion = 3;

  static const tableDrawerNavMenu = 'drawer_nav_menu';

  static Database? _database;

  static Future<Database> get database async {
    return _database ??= await _openDb();
  }

  static Future<Database> _openDb() async {
    final dbPath = '${await getDatabasesPath()}/$_dbName';
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Menu (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             icon TEXT,
             menu_name TEXT,
             url TEXT,
             ordering TEXT
          )
        ''');
        await _seedDrawerNavMenu(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2 từng thêm menu "Cuộc sống UEH" vào drawer; v3 bỏ đi vì chuyên
        // mục này mở từ chữ danh mục trên trang Tin tức.
        if (oldVersion == 2) {
          final removed = await db.query(
            tableDrawerNavMenu,
            where: 'menu_name = ?',
            whereArgs: ['Cuộc sống UEH'],
          );
          for (final row in removed) {
            await db.delete(
              tableDrawerNavMenu,
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            await db.rawUpdate(
              'UPDATE $tableDrawerNavMenu SET ordering = ordering - 1 '
              'WHERE ordering > ?',
              [row['ordering']],
            );
          }
        }
      },
    );
  }

  // Các menu item đang có trong AppDrawer.
  // icon_code là tên icon trong FontAwesomeIcons (vd: FontAwesomeIcons.newspaper).
  static Future<void> _seedDrawerNavMenu(Database db) async {
    const items = [
      {
        'icon_code': 'newspaper',
        'menu_name': 'Tin tức UEH',
        'menu_url': 'https://ueh.edu.vn/tintucmobile',
      },
      {
        'icon_code': 'calendarCheck',
        'menu_name': 'Sự kiện UEH',
        'menu_url': '',
      },
      {'icon_code': 'chartLine', 'menu_name': 'Xem điểm', 'menu_url': ''},
      {
        'icon_code': 'fingerprint',
        'menu_name': 'Định danh khuôn mặt',
        'menu_url': '',
      },
      {
        'icon_code': 'calendarDays',
        'menu_name': 'Thời khóa biểu',
        'menu_url': '',
      },
      {'icon_code': 'clipboardList', 'menu_name': 'Lịch thi', 'menu_url': ''},
      {
        'icon_code': 'heartPulse',
        'menu_name': 'Chăm sóc sức khỏe',
        'menu_url': '',
      },
      {
        'icon_code': 'leaf',
        'menu_name': 'UEH Go Green Station',
        'menu_url': '',
      },
      {
        'icon_code': 'phone',
        'menu_name': 'Liên hệ trực tiếp UEH',
        'menu_url': '',
      },
      {'icon_code': 'coins', 'menu_name': 'UEH Green Coin', 'menu_url': ''},
      {
        'icon_code': 'solidCircleCheck',
        'menu_name': 'Đã điểm danh',
        'menu_url': '',
      },
    ];

    final batch = db.batch();
    for (var i = 0; i < items.length; i++) {
      batch.insert(tableDrawerNavMenu, {...items[i], 'ordering': i + 1});
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, Object?>>> getDrawerNavMenus() async {
    final db = await database;
    return db.query(tableDrawerNavMenu, orderBy: 'ordering ASC');
  }

  static Future<List<DrawerNavMenu>> loadDrawerMenu() async {
    final rows = await getDrawerNavMenus();
    return rows.map(DrawerNavMenu.fromMap).toList();
  }
}
