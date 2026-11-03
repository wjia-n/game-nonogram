import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'nonogramstar'});
    expect(StoreService.starId, 'nonogramstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'nonogramcoffee', 'nonogramchocolate'});
    expect(StoreService.productIdsFor(TargetPlatform.android),
        isNot(contains('nonogramstar')));
  });
}
