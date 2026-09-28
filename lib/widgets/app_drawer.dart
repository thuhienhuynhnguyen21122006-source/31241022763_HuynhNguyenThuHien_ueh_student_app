import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../helpers/DbUtils.dart';

// Chuyển icon_code lưu trong DB sang icon FontAwesome.
// Thêm menu mới với icon khác thì bổ sung vào đây.
const Map<String, FaIconData> _iconsByCode = {
  'newspaper': FontAwesomeIcons.newspaper,
  'calendarCheck': FontAwesomeIcons.calendarCheck,
  'chartLine': FontAwesomeIcons.chartLine,
  'fingerprint': FontAwesomeIcons.fingerprint,
  'calendarDays': FontAwesomeIcons.calendarDays,
  'clipboardList': FontAwesomeIcons.clipboardList,
  'heartPulse': FontAwesomeIcons.heartPulse,
  'leaf': FontAwesomeIcons.leaf,
  'phone': FontAwesomeIcons.phone,
  'coins': FontAwesomeIcons.coins,
  'solidCircleCheck': FontAwesomeIcons.solidCircleCheck,
};

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final Future<List<DrawerNavMenu>> _menusFuture;

  @override
  void initState() {
    super.initState();
    _menusFuture = DbUtils.loadDrawerMenu();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<List<DrawerNavMenu>>(
        future: _menusFuture,
        builder: (context, snapshot) {
          final menus = snapshot.data ?? const <DrawerNavMenu>[];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF005F69)),
                child: Center(
                  child: Image(
                    image: ResizeImage(
                      AssetImage('asset/image/logo-header.png'),
                      width: 800,
                    ),
                  ),
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: Text('Không tải được menu: ${snapshot.error}'),
                )
              else
                for (final menu in menus)
                  ListTile(
                    leading: FaIcon(
                      _iconsByCode[menu.iconCode] ??
                          FontAwesomeIcons.solidCircle,
                      size: 20,
                    ),
                    title: Text(menu.menuName),
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
