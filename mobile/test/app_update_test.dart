import 'package:alcove/core/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares versions', () {
    expect(isNewer('0.19.0', '0.18.1'), isTrue);
    expect(isNewer('1.0.0', '0.99.9'), isTrue);
    expect(isNewer('0.18.1', '0.18.1'), isFalse);
    expect(isNewer('0.18.0', '0.18.1'), isFalse);
    expect(isNewer('v0.20.0', '0.19.9'), isTrue);
    expect(isNewer('0.18.1-3-gabc', '0.1.0'), isFalse); // development builds never offer updates
  });
}
