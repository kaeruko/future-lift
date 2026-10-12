/// A population-level illustrative comparison, not an individual's savings.
///
/// The studies use different populations and designs. Adding their cost gaps
/// after annualising is an explicit hypothetical scenario, NOT an effect-size
/// estimate for a mission, a prediction, or a tax/public-funding saving.
///
/// Yoshizawa et al. (2016), doi:10.1155/2016/7530105
/// 60 intervention participants (mean age 63.1) vs 300 comparators:
/// total medical expenditure gap USD 640.4 / year.
/// The paper used 108 JPY/USD to convert its monetary data.
///
/// Hirai et al. (2021), doi:10.3390/ijerph18095004
/// JAGES cohort 38,875 adults aged >=65, 59-month follow-up:
/// cumulative LTCI-cost gap USD 600 between people who went out
/// almost daily and those who went out at most once per week.
/// The paper used 100 JPY/USD.
abstract final class SocialSecurityStudyIllustration {
  static const double medicalGapUsdPerYear = 640.4;
  static const int medicalStudyYenPerUsd = 108;
  static const int careGapUsdPerFollowUp = 600;
  static const int careStudyYenPerUsd = 100;
  static const int careFollowUpMonths = 59;

  static double get medicalGapYenPerYear =>
      medicalGapUsdPerYear * medicalStudyYenPerUsd;

  static double get careGapYenPerYear =>
      careGapUsdPerFollowUp * careStudyYenPerUsd * 12 /
      careFollowUpMonths;

  /// Rounded to the nearest thousand yen to avoid false precision.
  /// This is a fixed cross-study illustration: never add it per mission.
  static int get illustrativeAnnualGapYen =>
      ((medicalGapYenPerYear + careGapYenPerYear) / 1000).round() * 1000;

  static String get illustratedYenLabel {
    final digits = illustrativeAnnualGapYen.toString();
    if (digits.length <= 3) return digits;
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return grouped.toString();
  }

  static const String methodologyNote =
      '※異なる国内研究2件の集団間費用差を便宜的に年換算・合算した参考試算です。'
      '医療費：運動教室参加群と非参加群の年額差640.4米ドル（2016年、1ドル＝108円）。'
      '介護費：外出がほぼ毎日の群と週1回以下の群の59か月累積差600米ドル'
      '（2021年、1ドル＝100円）。'
      '対象者・調査期間・比較条件が異なるため、同一人への効果は検証されていません。'
      'このミッション1回で削減した額や、税金・公費の削減額ではありません。';
}
