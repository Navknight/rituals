import 'package:flutter_test/flutter_test.dart';
import 'package:rituals/services/update_service.dart';

void main() {
  test('isNewer compares numerically, not as text', () {
    expect(isNewer('0.1.10', '0.1.9'), isTrue);
    expect(isNewer('0.2.0', '0.1.5'), isTrue);
    expect(isNewer('0.1.5', '0.1.5'), isFalse);
    expect(isNewer('0.1.4', '0.1.5'), isFalse);
    expect(isNewer('1.0', '0.9.9'), isTrue);
    // A build without a version name never nags.
    expect(isNewer('0.1.5', ''), isTrue);
  });
}
