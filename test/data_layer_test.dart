import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare/data/account_store.dart';
import 'package:healthcare/data/auth_repository.dart';
import 'package:healthcare/data/nutrition_repository.dart';
import 'package:healthcare/data/workout_repository.dart';
import 'package:healthcare/models/health_metric.dart';
import 'package:healthcare/models/nutrition.dart';
import 'package:healthcare/models/user.dart';
import 'package:healthcare/models/workout.dart';
import 'package:healthcare/utils/sha256.dart';

void main() {
  // Nạp danh mục món ăn cần rootBundle, nên phải khởi tạo binding trước.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Kiểm thử không cần chờ độ trễ giả lập.
    AuthRepository.simulatedLatency = Duration.zero;
  });

  group('Hàm băm SHA-256', () {
    // Các giá trị dưới đây là bộ kiểm thử chuẩn của SHA-256 (FIPS 180-4),
    // dùng để chứng minh hàm băm tự viết cho ra kết quả đúng.
    test('băm đúng với xâu rỗng', () {
      expect(
        sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('băm đúng với "abc"', () {
      expect(
        sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('băm đúng với chuỗi dài hơn một khối dữ liệu', () {
      expect(
        sha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });
  });

  group('Băm mật khẩu', () {
    test('cùng mật khẩu nhưng khác email thì cho giá trị băm khác nhau', () {
      final first = hashPassword('123456', 'a@gmail.com');
      final second = hashPassword('123456', 'b@gmail.com');

      expect(first, isNot(equals(second)));
    });

    test('cùng email và mật khẩu thì cho cùng giá trị băm', () {
      expect(
        hashPassword('123456', 'a@gmail.com'),
        hashPassword('123456', 'a@gmail.com'),
      );
    });

    test('email viết hoa hay thường đều cho cùng kết quả', () {
      expect(
        hashPassword('123456', 'A@Gmail.com'),
        hashPassword('123456', 'a@gmail.com'),
      );
    });
  });

  group('Đăng nhập', () {
    late AuthRepository auth;

    setUp(() {
      auth = AuthRepository();
    });

    test('đăng nhập thành công bằng tài khoản mẫu', () async {
      final user = await auth.login(
        email: InMemoryAccountStore.demoEmail,
        password: InMemoryAccountStore.demoPassword,
      );

      expect(user.fullName, 'Minh Anh');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.email, InMemoryAccountStore.demoEmail);
    });

    test('email không phân biệt chữ hoa chữ thường', () async {
      await auth.login(
        email: 'MinhAnh@Gmail.com',
        password: InMemoryAccountStore.demoPassword,
      );

      expect(auth.isLoggedIn, isTrue);
    });

    test('sai mật khẩu thì báo lỗi và chưa đăng nhập', () async {
      expect(
        () => auth.login(
          email: InMemoryAccountStore.demoEmail,
          password: 'sai-mat-khau',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.isLoggedIn, isFalse);
    });

    test('email chưa tồn tại thì báo lỗi', () async {
      expect(
        () => auth.login(email: 'khongton@gmail.com', password: '123456'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'thông báo',
            'Email hoặc mật khẩu không đúng.',
          ),
        ),
      );
    });

    test('bỏ trống thông tin thì báo lỗi', () async {
      expect(
        () => auth.login(email: '', password: ''),
        throwsA(isA<AuthException>()),
      );
    });

    test('đăng xuất thì xóa người dùng hiện tại', () async {
      await auth.login(
        email: InMemoryAccountStore.demoEmail,
        password: InMemoryAccountStore.demoPassword,
      );
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
    });
  });

  group('Đăng ký', () {
    late AuthRepository auth;

    setUp(() {
      auth = AuthRepository();
    });

    test('đăng ký thành công thì đăng nhập luôn', () async {
      final user = await auth.register(
        fullName: 'Nguyễn Văn A',
        email: 'vana@gmail.com',
        password: 'matkhau123',
        confirmPassword: 'matkhau123',
      );

      expect(user.fullName, 'Nguyễn Văn A');
      expect(user.email, 'vana@gmail.com');
      expect(auth.isLoggedIn, isTrue);
    });

    test('mật khẩu được lưu dưới dạng đã băm, không phải văn bản gốc', () async {
      final user = await auth.register(
        fullName: 'Nguyễn Văn A',
        email: 'vana@gmail.com',
        password: 'matkhau123',
        confirmPassword: 'matkhau123',
      );

      expect(user.passwordHash, isNot(equals('matkhau123')));
      expect(user.passwordHash, hashPassword('matkhau123', 'vana@gmail.com'));
    });

    test('email đã tồn tại thì không cho đăng ký', () async {
      expect(
        () => auth.register(
          fullName: 'Người Trùng',
          email: InMemoryAccountStore.demoEmail,
          password: 'matkhau123',
          confirmPassword: 'matkhau123',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'thông báo',
            'Email này đã được đăng ký.',
          ),
        ),
      );
    });

    test('mật khẩu nhập lại không khớp thì báo lỗi', () async {
      expect(
        () => auth.register(
          fullName: 'Nguyễn Văn A',
          email: 'vana@gmail.com',
          password: 'matkhau123',
          confirmPassword: 'khac123',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'thông báo',
            'Mật khẩu nhập lại không khớp.',
          ),
        ),
      );
    });

    test('mật khẩu ngắn hơn 6 ký tự thì báo lỗi', () async {
      expect(
        () => auth.register(
          fullName: 'Nguyễn Văn A',
          email: 'vana@gmail.com',
          password: '123',
          confirmPassword: '123',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('email sai định dạng thì báo lỗi', () async {
      expect(
        () => auth.register(
          fullName: 'Nguyễn Văn A',
          email: 'vana.gmail.com',
          password: 'matkhau123',
          confirmPassword: 'matkhau123',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('họ tên để trống thì báo lỗi', () async {
      expect(
        () => auth.register(
          fullName: '   ',
          email: 'vana@gmail.com',
          password: 'matkhau123',
          confirmPassword: 'matkhau123',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('Kiểm tra định dạng email', () {
    test('nhận các email hợp lệ', () {
      expect(AuthRepository.isValidEmail('a@gmail.com'), isTrue);
      expect(AuthRepository.isValidEmail('nguyen.van.a@sv.edu.vn'), isTrue);
      expect(AuthRepository.isValidEmail('user+tag@domain.co'), isTrue);
    });

    test('từ chối các email sai', () {
      expect(AuthRepository.isValidEmail('a@gmail'), isFalse);
      expect(AuthRepository.isValidEmail('a gmail.com'), isFalse);
      expect(AuthRepository.isValidEmail('@gmail.com'), isFalse);
      expect(AuthRepository.isValidEmail('a@@gmail.com'), isFalse);
    });
  });

  group('Đổi mật khẩu', () {
    late AuthRepository auth;

    setUp(() async {
      auth = AuthRepository();
      await auth.login(
        email: InMemoryAccountStore.demoEmail,
        password: InMemoryAccountStore.demoPassword,
      );
    });

    test('đổi mật khẩu thành công thì đăng nhập được bằng mật khẩu mới',
        () async {
      await auth.changePassword(
        currentPassword: InMemoryAccountStore.demoPassword,
        newPassword: 'matkhaumoi1',
        confirmPassword: 'matkhaumoi1',
      );

      await auth.logout();
      await auth.login(
        email: InMemoryAccountStore.demoEmail,
        password: 'matkhaumoi1',
      );
      expect(auth.isLoggedIn, isTrue);
    });

    test('mật khẩu hiện tại sai thì không đổi được', () async {
      expect(
        () => auth.changePassword(
          currentPassword: 'sai-mat-khau',
          newPassword: 'matkhaumoi1',
          confirmPassword: 'matkhaumoi1',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'thông báo',
            'Mật khẩu hiện tại không đúng.',
          ),
        ),
      );
    });
  });

  group('Hồ sơ người dùng', () {
    test('cập nhật cân nặng thì thêm một bản ghi chỉ số mới', () async {
      final auth = AuthRepository();
      await auth.login(
        email: InMemoryAccountStore.demoEmail,
        password: InMemoryAccountStore.demoPassword,
      );

      final metric = await auth.updateProfile(weightKg: 55.0);

      expect(metric, isNotNull);
      expect(metric!.type, HealthMetricType.weight);
      expect(metric.value, 55.0);
      expect(auth.currentUser?.weightKg, 55.0);
    });

    test('đổi cân nặng thì BMI được tính lại', () async {
      final auth = AuthRepository();
      await auth.login(
        email: InMemoryAccountStore.demoEmail,
        password: InMemoryAccountStore.demoPassword,
      );

      final heightM = auth.currentUser!.heightCm / 100;
      final expectedBmi = 55.0 / (heightM * heightM);

      await auth.updateProfile(weightKg: 55.0);

      expect(auth.currentUser!.bmi, closeTo(expectedBmi, 0.001));
    });

    test('xếp loại BMI đúng theo ngưỡng', () {
      final base = User(
        id: 'u',
        fullName: 'Test',
        email: 't@gmail.com',
        passwordHash: 'x',
        heightCm: 170,
        createdAt: DateTime(2026),
      );

      expect(base.copyWith(weightKg: 50, heightCm: 170).bmiLabel, 'Thiếu cân');
      expect(base.copyWith(weightKg: 65, heightCm: 170).bmiLabel, 'Bình thường');
      // BMI xếp loại theo chuẩn WHO Châu Á (dùng chung với HealthAssessor):
      // 23.0–24.9 là Thừa cân, từ 25.0 trở lên là Béo phì.
      expect(base.copyWith(weightKg: 70, heightCm: 170).bmiLabel, 'Thừa cân');
      expect(base.copyWith(weightKg: 78, heightCm: 170).bmiLabel, 'Béo phì');
      expect(base.copyWith(weightKg: 95, heightCm: 170).bmiLabel, 'Béo phì');
    });
  });

  group('Chỉ số sức khỏe', () {
    test('hiển thị giá trị kèm đơn vị, bỏ số 0 thừa', () {
      final metric = HealthMetric(
        id: 'm1',
        userId: 'u1',
        type: HealthMetricType.weight,
        value: 56.5,
        recordedAt: DateTime(2026),
      );
      expect(metric.displayValue, '56.5 kg');

      final heartRate = HealthMetric(
        id: 'm2',
        userId: 'u1',
        type: HealthMetricType.heartRate,
        value: 72,
        recordedAt: DateTime(2026),
      );
      expect(heartRate.displayValue, '72 bpm');
    });

    test('huyết áp hiển thị cả hai chỉ số', () {
      final metric = HealthMetric(
        id: 'm3',
        userId: 'u1',
        type: HealthMetricType.bloodPressure,
        value: 120,
        valueSecondary: 80,
        recordedAt: DateTime(2026),
      );

      expect(metric.displayValue, '120/80 mmHg');
    });

    test('lưu và đọc lại từ map giữ nguyên dữ liệu', () {
      final metric = HealthMetric(
        id: 'm4',
        userId: 'u1',
        type: HealthMetricType.bloodGlucose,
        value: 95,
        recordedAt: DateTime(2026, 9, 28, 7, 30),
        note: 'Đo lúc đói',
      );

      final restored = HealthMetric.fromMap(metric.toMap());

      expect(restored.id, metric.id);
      expect(restored.type, metric.type);
      expect(restored.value, metric.value);
      expect(restored.note, metric.note);
      expect(restored.recordedAt, metric.recordedAt);
    });
  });

  group('Dinh dưỡng', () {
    test('thêm món thì tổng calo và nhóm chất tăng theo', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      final pho = repository.catalog.firstWhere((food) => food.id == 'food-pho-bo');
      await repository.addFood(
        userId: 'u1',
        food: pho,
        slot: MealSlot.breakfast,
        calorieGoal: 2000,
      );

      expect(repository.summary.calories, pho.calories);
      expect(repository.summary.protein, closeTo(pho.protein, 0.001));
      expect(repository.summary.carbs, closeTo(pho.carbs, 0.001));
      expect(repository.summary.fat, closeTo(pho.fat, 0.001));
    });

    test('chọn nửa phần thì dinh dưỡng giảm một nửa', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      final pho = repository.catalog.firstWhere((food) => food.id == 'food-pho-bo');
      await repository.addFood(
        userId: 'u1',
        food: pho,
        slot: MealSlot.lunch,
        calorieGoal: 2000,
        portion: 0.5,
      );

      expect(repository.summary.calories, (pho.calories / 2).round());
      expect(repository.summary.protein, closeTo(pho.protein / 2, 0.001));
    });

    test('xóa món thì tổng calo trở về 0', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      final pho = repository.catalog.firstWhere((food) => food.id == 'food-pho-bo');
      final entry = await repository.addFood(
        userId: 'u1',
        food: pho,
        slot: MealSlot.dinner,
        calorieGoal: 2000,
      );
      expect(repository.summary.calories, greaterThan(0));

      await repository.removeEntry(
        userId: 'u1',
        entryId: entry.id,
        calorieGoal: 2000,
      );

      expect(repository.summary.calories, 0);
      expect(repository.todayEntries, isEmpty);
    });

    test('mô tả bữa ăn nối tên các món đã thêm', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      final pho = repository.catalog.firstWhere((food) => food.id == 'food-pho-bo');
      final trung =
          repository.catalog.firstWhere((food) => food.id == 'food-trung-luoc');

      await repository.addFood(
        userId: 'u1',
        food: pho,
        slot: MealSlot.breakfast,
        calorieGoal: 2000,
      );
      await repository.addFood(
        userId: 'u1',
        food: trung,
        slot: MealSlot.breakfast,
        calorieGoal: 2000,
      );

      expect(repository.mealDescription(MealSlot.breakfast), 'Phở bò + Trứng luộc');
      expect(repository.mealDescription(MealSlot.lunch), 'Chưa thêm món ăn');
      expect(
        repository.mealCalories(MealSlot.breakfast),
        pho.calories + trung.calories,
      );
    });

    test('tìm kiếm theo từ khóa không phân biệt chữ hoa chữ thường', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      final result = repository.search(keyword: 'phở');

      expect(result.map((food) => food.name), contains('Phở bò'));
    });

    test('tìm kiếm theo nhóm món ăn', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      final drinks = repository.search(category: FoodCategory.drink);

      expect(drinks, isNotEmpty);
      expect(
        drinks.every((food) => food.category == FoodCategory.drink),
        isTrue,
      );
    });

    test('phần trăm calo không vượt 100 dù nạp quá mục tiêu', () async {
      final repository = NutritionRepository();
      await repository.loadCatalog();

      for (final food in repository.catalog) {
        await repository.addFood(
          userId: 'u1',
          food: food,
          slot: MealSlot.lunch,
          calorieGoal: 500,
        );
      }

      expect(repository.summary.calorieProgress, lessThanOrEqualTo(1.0));
      expect(repository.summary.caloriePercent, lessThanOrEqualTo(100));
      expect(repository.summary.remainingCalories, lessThan(0));
    });
  });

  group('Tập luyện', () {
    test('hoàn thành bài tập thì cộng dồn thời gian và năng lượng', () async {
      final repository = WorkoutRepository();
      await repository.loadCatalog();

      final yoga = repository.catalog.firstWhere((w) => w.id == 'workout-yoga');
      final cardio =
          repository.catalog.firstWhere((w) => w.id == 'workout-cardio-nhe');

      await repository.completeWorkout(userId: 'u1', workout: yoga);
      await repository.completeWorkout(userId: 'u1', workout: cardio);

      expect(repository.todayLogs.length, 2);
      expect(
        repository.minutesToday,
        yoga.durationMinutes + cardio.durationMinutes,
      );
      expect(
        repository.caloriesBurnedToday,
        yoga.caloriesBurned + cardio.caloriesBurned,
      );
    });

    test('tiến trình mục tiêu không vượt 100 phần trăm', () async {
      final repository = WorkoutRepository();
      await repository.loadCatalog();

      for (final workout in repository.catalog) {
        await repository.completeWorkout(userId: 'u1', workout: workout);
      }

      expect(repository.minutesToday, greaterThan(60));
      expect(repository.goalProgress, 1.0);
      expect(repository.goalPercent, 100);
    });

    test('nhật ký tách riêng theo từng người dùng', () async {
      final repository = WorkoutRepository();
      await repository.loadCatalog();

      final yoga = repository.catalog.firstWhere((w) => w.id == 'workout-yoga');
      await repository.completeWorkout(userId: 'u1', workout: yoga);

      expect(repository.todayLogs, isNotEmpty);

      await repository.loadDay('u2');
      expect(repository.todayLogs, isEmpty);
    });

    test('lưu và đọc lại bài tập từ map giữ nguyên dữ liệu', () {
      const workout = Workout(
        id: 'w1',
        name: 'Yoga',
        durationMinutes: 15,
        caloriesBurned: 90,
        intensity: WorkoutIntensity.light,
        category: 'Thư giãn',
      );

      final restored = Workout.fromMap(workout.toMap());

      expect(restored.name, workout.name);
      expect(restored.durationMinutes, workout.durationMinutes);
      expect(restored.intensity, workout.intensity);
      expect(restored.subtitle, '15 phút · Thư giãn');
    });
  });

  group('Lưu trữ tài khoản', () {
    test('tài khoản mẫu đăng nhập được bằng mật khẩu 123456', () async {
      final store = InMemoryAccountStore.withDemoAccount();

      final user = await store.findByEmail(InMemoryAccountStore.demoEmail);

      expect(user, isNotNull);
      expect(user!.passwordHash,
          hashPassword(InMemoryAccountStore.demoPassword, user.email));
    });

    test('tìm theo email không phân biệt chữ hoa chữ thường', () async {
      final store = InMemoryAccountStore.withDemoAccount();

      final user = await store.findByEmail('MINHANH@GMAIL.COM');

      expect(user, isNotNull);
      expect(user!.fullName, 'Minh Anh');
    });

    test('thêm tài khoản mới rồi tìm lại được', () async {
      final store = InMemoryAccountStore();
      final user = User(
        id: 'u9',
        fullName: 'Người Mới',
        email: 'moi@gmail.com',
        passwordHash: hashPassword('123456', 'moi@gmail.com'),
        createdAt: DateTime(2026),
      );

      await store.insert(user);

      expect((await store.findById('u9'))?.fullName, 'Người Mới');
      expect((await store.findByEmail('moi@gmail.com'))?.id, 'u9');
      expect((await store.all()).length, 1);
    });
  });
}
