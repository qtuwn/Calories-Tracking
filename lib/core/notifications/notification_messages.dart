import 'dart:math';

/// Categories for notification messages
enum NotificationCategory {
  breakfast,
  lunch,
  dinner,
  exercise,
  water,
  general,
}

/// Message pool for breakfast reminders
const breakfastMessages = <String>[
  'Chúc buổi sáng! Nhớ ghi lại bữa sáng để bắt đầu ngày mới đủ năng lượng nhé 🌞',
  'Đã tới lúc ăn sáng rồi đó! Bỏ qua bữa sáng dễ khiến bạn ăn nhiều hơn vào tối đó nha 🍞',
  'Một ngày mới khỏe mạnh = một bữa sáng đầy đủ! Nhớ ghi lại nha.',
];

/// Message pool for lunch reminders
const lunchMessages = <String>[
  'Đến giờ ghi lại bữa trưa rồi! Giữ thói quen tốt sẽ dễ đạt mục tiêu hơn 🍚',
  'Nạp năng lượng giữa ngày nào! Bạn đã ăn gì cho bữa trưa hôm nay?',
  'Một chút ghi chú nhỏ cho Ăn Khoẻ: bữa trưa của bạn hôm nay là gì?',
];

/// Message pool for dinner reminders
const dinnerMessages = <String>[
  'Buổi tối nhẹ nhàng, đừng quên ghi lại bữa ăn nhé 🌙',
  'Check-in bữa tối nè! Mục tiêu calo đang chờ bạn hoàn thành.',
  'Bạn đã ăn tối chưa? Ăn Khoẻ muốn biết để tính chính xác cho bạn!',
];

/// Message pool for water reminders
const waterMessages = <String>[
  'Uống một ngụm nước cho tươi tỉnh nào 💧',
  'Nay bạn uống đủ nước chưa? Nhấp một ít nước giúp cơ thể làm việc tốt hơn.',
  'Đã đến giờ bổ sung nước! Một chút là đủ để làm mới cơ thể.',
  'Cơ thể bạn cần nước để hoạt động suôn sẻ đó. Uống thêm chút nhé!',
];

/// Message pool for exercise reminders
const exerciseMessages = <String>[
  'Đã đến lúc vận động rồi! 15 phút đi bộ giúp bạn tiêu calo và giảm stress.',
  'Giãn cơ nhẹ thôi cũng giúp bạn cảm thấy dễ chịu hơn! Nhắc nhẹ nè 💪',
  'Một bài tập nho nhỏ giúp cơ thể tỉnh táo hơn. Bắt đầu không?',
  'Hôm nay bạn đã tập chưa? Đừng để cơ thể ngồi một chỗ quá lâu nha.',
];

/// Message pool for general motivation (prepared for future use)
const generalMessages = <String>[
  'Những thay đổi nhỏ mỗi ngày sẽ dẫn đến kết quả lớn. Bạn đang đi đúng hướng rồi.',
  'Tự tin lên nào! Bạn làm tốt hơn bạn nghĩ đấy.',
  'Đừng quên chăm sóc bản thân. Ăn đủ, ngủ đủ, uống nước đủ nha 🌿',
  'Tiếp tục duy trì thói quen tốt. Cơ thể sẽ cảm ơn bạn!',
];

/// Random number generator instance (shared for consistency)
final _random = Random();

/// Returns a random message from the specified notification category
/// 
/// This is a pure function with no framework dependencies, making it easy to unit test.
/// Returns an empty string if the message pool for the category is empty.
String randomNotificationMessage(NotificationCategory category) {
  List<String> pool;
  switch (category) {
    case NotificationCategory.breakfast:
      pool = breakfastMessages;
      break;
    case NotificationCategory.lunch:
      pool = lunchMessages;
      break;
    case NotificationCategory.dinner:
      pool = dinnerMessages;
      break;
    case NotificationCategory.exercise:
      pool = exerciseMessages;
      break;
    case NotificationCategory.water:
      pool = waterMessages;
      break;
    case NotificationCategory.general:
      pool = generalMessages;
      break;
  }

  if (pool.isEmpty) return '';
  return pool[_random.nextInt(pool.length)];
}

