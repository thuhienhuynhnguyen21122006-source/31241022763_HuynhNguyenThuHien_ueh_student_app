import 'package:flutter_test/flutter_test.dart';
import 'package:ueh_student/main.dart';

void main() {
  testWidgets('UEH Student app khởi động', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Trang chủ'), findsWidgets);
  });
}
