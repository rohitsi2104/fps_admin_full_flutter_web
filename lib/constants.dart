/// Order status string constants — must match backend values exactly.
abstract class OrderStatus {
  static const pending = 'PENDING';
  static const confirmed = 'CONFIRMED';
  static const received = 'RECEIVED';
  static const ready = 'READY';
  static const delivered = 'DELIVERED';
  static const cancelled = 'CANCELLED';

  static const all = [pending, confirmed, received, ready, delivered, cancelled];

  static String display(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case confirmed:
        return 'Confirmed';
      case received:
        return 'Received';
      case ready:
        return 'Ready';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}
