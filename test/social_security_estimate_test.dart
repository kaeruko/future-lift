import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/social_security_estimate.dart';

void main() {
  test('medical study gap uses the paper historical exchange rate', () {
    expect(
      SocialSecurityStudyIllustration.medicalGapYenPerYear,
      closeTo(69163.2, 0.0001),
    );
  });

  test('care study cost difference is annualised from 59 months', () {
    expect(
      SocialSecurityStudyIllustration.careGapYenPerYear,
      closeTo(60000 * 12 / 59, 0.0001),
    );
  });

  test('cross-study hypothetical figure is rounded, never per mission', () {
    expect(SocialSecurityStudyIllustration.illustrativeAnnualGapYen, 81000);
    expect(SocialSecurityStudyIllustration.illustratedYenLabel, '81,000');
    expect(
      SocialSecurityStudyIllustration.methodologyNote,
      contains('このミッション1回で削減した額'),
    );
  });
}
