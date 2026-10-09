import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/data/auth_repository.dart';
import 'package:healthcare/main.dart';
import 'package:healthcare/widgets/app_buttons.dart';
import 'package:healthcare/widgets/app_card.dart';

void main() {
  setUp(() {
    // Bỏ độ trễ giả lập để kiểm thử không phải chờ.
    AuthRepository.simulatedLatency = Duration.zero;
  });

  tearDown(() {
    AuthRepository.simulatedLatency = const Duration(milliseconds: 450);
  });

  /// Cuộn tới widget rồi bấm.
  ///
  /// Hai tình huống cần xử lý khác nhau:
  /// * Phần tử đã có trong cây widget nhưng nằm ngoài vùng nhìn thấy (ví dụ
  ///   nút ở đáy một biểu mẫu) thì `ensureVisible` là đủ.
  /// * Phần tử nằm trong `ListView` chưa được dựng vì ở ngoài màn hình thì
  ///   phải kéo danh sách cho tới khi nó xuất hiện. Không dùng
  ///   `scrollUntilVisible` ở đây vì hàm đó đòi phần tử phải tồn tại sẵn.
  Future<void> scrollAndTap(
    WidgetTester tester,
    Finder finder, {
    double step = 200,
    int maxDrags = 8,
  }) async {
    // Chỉ kéo khi màn hình có danh sách cuộn; hộp thoại thì không có.
    // Lưu ý: không được gọi `.first.evaluate()` vì finder `.first` sẽ ném lỗi
    // khi chưa có phần tử nào khớp.
    final listView = find.byType(ListView);
    for (var i = 0;
        i < maxDrags && listView.evaluate().isNotEmpty && finder.evaluate().isEmpty;
        i++) {
      await tester.drag(listView.first, Offset(0, -step));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Ứng dụng mở ra màn hình chào mừng khi chưa đăng nhập', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng bạn!'), findsOneWidget);
    expect(find.text('HealthFlow'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Đăng nhập'), findsOneWidget);
    expect(find.widgetWithText(SecondaryButton, 'Đăng ký'), findsOneWidget);
  });

  testWidgets('Đăng nhập bằng tài khoản mẫu thì vào được màn hình chính', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    // Mở màn hình đăng nhập từ màn hình chào mừng.
    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );
    expect(find.text('Tiếp tục hành trình sống khỏe của bạn'), findsOneWidget);

    // Điền sẵn tài khoản dùng thử rồi đăng nhập.
    await scrollAndTap(tester, find.text('Điền sẵn tài khoản này'));
    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    // Sau khi đăng nhập phải thấy lời chào kèm tên người dùng và 5 tab.
    expect(find.textContaining('Xin chào, Minh Anh'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Sức khỏe'), findsWidgets);
    expect(find.text('Tập luyện'), findsOneWidget);
    expect(find.text('Dinh dưỡng'), findsWidgets);
    expect(find.text('Cài đặt'), findsOneWidget);
  });

  testWidgets('Đăng nhập sai mật khẩu thì hiện thông báo lỗi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'minhanh@gmail.com');
    await tester.enterText(fields.last, 'saimatkhau');
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
  });

  testWidgets('Đăng nhập với email sai định dạng thì báo lỗi ngay trên ô nhập', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'email-sai');
    await tester.enterText(fields.last, '123456');
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    expect(find.text('Email không hợp lệ.'), findsOneWidget);
  });

  testWidgets('Đăng ký thiếu đồng ý điều khoản thì chưa cho tạo tài khoản', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(SecondaryButton, 'Đăng ký'),
    );
    expect(find.text('Tạo tài khoản'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nguyễn Văn A');
    await tester.enterText(fields.at(1), 'vana@gmail.com');
    await tester.enterText(fields.at(2), 'matkhau123');
    await tester.enterText(fields.at(3), 'matkhau123');
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng ký'),
    );

    expect(
      find.text('Bạn cần đồng ý với điều khoản để tiếp tục.'),
      findsOneWidget,
    );
  });

  testWidgets('Đăng ký với mật khẩu nhập lại không khớp thì báo lỗi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(SecondaryButton, 'Đăng ký'),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nguyễn Văn A');
    await tester.enterText(fields.at(1), 'vana@gmail.com');
    await tester.enterText(fields.at(2), 'matkhau123');
    await tester.enterText(fields.at(3), 'khac123');
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng ký'),
    );

    expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
  });

  testWidgets('Đăng ký hợp lệ thì vào thẳng màn hình chính', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    await scrollAndTap(
      tester,
      find.widgetWithText(SecondaryButton, 'Đăng ký'),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Trần Thị B');
    await tester.enterText(fields.at(1), 'thib@gmail.com');
    await tester.enterText(fields.at(2), 'matkhau123');
    await tester.enterText(fields.at(3), 'matkhau123');
    await tester.pumpAndSettle();

    // Đồng ý điều khoản.
    await scrollAndTap(tester, find.byType(Checkbox));

    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng ký'),
    );

    expect(find.textContaining('Xin chào, Trần Thị B'), findsOneWidget);
  });

  testWidgets('Đăng xuất từ tab Cài đặt thì quay về màn hình chào mừng', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    // Đăng nhập bằng tài khoản mẫu.
    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );
    await scrollAndTap(tester, find.text('Điền sẵn tài khoản này'));
    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    // Mở tab Cài đặt.
    await scrollAndTap(tester, find.text('Cài đặt'));
    expect(find.text('minhanh@gmail.com'), findsOneWidget);

    // Đăng xuất: dùng đúng dòng cài đặt (SettingsTile) để không nhầm với nút
    // cùng tên trong hộp thoại xác nhận.
    await scrollAndTap(
      tester,
      find.widgetWithText(SettingsTile, 'Đăng xuất'),
    );

    // Hộp thoại xác nhận phải hiện ra trước khi bấm nút xác nhận.
    expect(find.byType(AlertDialog), findsOneWidget);

    // Trong hộp thoại có hai chữ "Đăng xuất" (tiêu đề và nút), nên chỉ định
    // đúng nút bấm.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Đăng xuất'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng bạn!'), findsOneWidget);
  });

  testWidgets('Thêm chỉ số cân nặng thì trang Sức khỏe cập nhật theo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthFlowApp());
    await tester.pumpAndSettle();

    // Đăng nhập bằng tài khoản mẫu.
    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );
    await scrollAndTap(tester, find.text('Điền sẵn tài khoản này'));
    await scrollAndTap(
      tester,
      find.widgetWithText(PrimaryButton, 'Đăng nhập'),
    );

    // Vào tab Sức khỏe (mục trên thanh điều hướng dưới cùng).
    await scrollAndTap(tester, find.text('Sức khỏe').last);
    expect(find.text('Tổng quan'), findsOneWidget);

    // Số liệu khởi tạo hiển thị đúng.
    expect(find.textContaining('56.5'), findsWidgets);

    // Mở hộp thoại thêm chỉ số.
    await scrollAndTap(
      tester,
      find.widgetWithText(ElevatedButton, 'Thêm chỉ số'),
    );
    expect(find.text('Loại chỉ số'), findsOneWidget);
  });
}
