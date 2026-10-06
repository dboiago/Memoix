import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/app/theme/colours.dart';

void main() {
  group('MemoixColors.forContinentDot multi-country terms', () {
    const parents = {
      'latin': 'latin american',
      'levantine': 'middle eastern',
      'southeast asian': 'asian',
      'east asian': 'asian',
      'south asian': 'asian',
    };

    parents.forEach((term, parent) {
      test('$term matches $parent and not the fallback', () {
        expect(MemoixColors.forContinentDot(term), MemoixColors.forContinentDot(parent));
        expect(
          MemoixColors.forContinentDot(term),
          isNot(MemoixColors.forContinentDot('zorblax')),
        );
      });
    });
  });
}
