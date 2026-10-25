import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Nhãn ML Kit (tiếng Anh) -> từ khóa tìm trong danh mục món Việt.
/// shortcut: ML Kit chỉ nhận ra loại món/thực phẩm chung (noodle, rice, fruit...),
/// không phân biệt phở với bún; nâng cấp bằng mô hình tự huấn luyện nếu cần.
const _keywords = {
  'rice': 'cơm', 'noodle': 'bún', 'pasta': 'mì', 'soup': 'canh',
  'salad': 'gỏi', 'bread': 'bánh mì', 'sandwich': 'bánh mì',
  'baguette': 'bánh mì', 'cake': 'bánh', 'dessert': 'chè',
  'egg': 'trứng', 'chicken': 'gà', 'fish': 'cá', 'seafood': 'tôm',
  'shrimp': 'tôm', 'pork': 'heo', 'beef': 'bò', 'steak': 'bò',
  'meat': 'thịt', 'vegetable': 'rau', 'banana': 'chuối', 'orange': 'cam',
  'apple': 'táo', 'mango': 'xoài', 'watermelon': 'dưa hấu',
  'strawberry': 'dâu', 'fruit': 'trái cây', 'coffee': 'cà phê',
  'tea': 'trà', 'juice': 'nước', 'milk': 'sữa', 'pizza': 'pizza',
  'hamburger': 'hamburger', 'sushi': 'sushi',
};

class FoodGuess {
  const FoodGuess(this.label, this.keyword);
  final String label;
  final String keyword;
}

/// Nhận diện sơ bộ món trong ảnh (chạy trên máy). Trả về null nếu không có
/// nhãn nào khớp; khi đó người dùng vẫn tìm tay như bình thường.
Future<FoodGuess?> guessFoodFromPhoto(String path) async {
  final labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.4),
  );
  try {
    final labels = await labeler.processImage(InputImage.fromFilePath(path));
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    for (final l in labels) {
      final k = _keywords[l.label.toLowerCase()];
      if (k != null) return FoodGuess(l.label, k);
    }
    return null;
  } finally {
    await labeler.close();
  }
}
