import 'package:adhan_dart/adhan_dart.dart';

/// The conventional calculation method for each country that has one.
///
/// Fajr and Isha depend on a twilight angle that no two authorities agree on
/// (Umm al-Qura uses 18.5° and a fixed 90-minute Isha interval, Karachi 18°/18°,
/// ISNA 15°/15°), and prayer timetables in a given country follow that
/// country's convention. Picking the wrong one shifts Fajr and Isha by 10–25
/// minutes, which rarely changes which window we land in but is free to get
/// right. Countries not listed fall back to Muslim World League.
const _methodsByCountry = <String, CalculationParameters Function()>{
  'DZ': CalculationMethodParameters.algerian,
  'AE': CalculationMethodParameters.dubai,
  'EG': CalculationMethodParameters.egyptian,
  'FR': CalculationMethodParameters.france,
  'BH': CalculationMethodParameters.gulfRegion,
  'OM': CalculationMethodParameters.gulfRegion,
  'ID': CalculationMethodParameters.indonesian,
  'IR': CalculationMethodParameters.tehran,
  'JO': CalculationMethodParameters.jordan,
  'AF': CalculationMethodParameters.karachi,
  'BD': CalculationMethodParameters.karachi,
  'IN': CalculationMethodParameters.karachi,
  'PK': CalculationMethodParameters.karachi,
  'KW': CalculationMethodParameters.kuwait,
  'MA': CalculationMethodParameters.morocco,
  'CA': CalculationMethodParameters.northAmerica,
  'MX': CalculationMethodParameters.northAmerica,
  'US': CalculationMethodParameters.northAmerica,
  'PT': CalculationMethodParameters.portugal,
  'QA': CalculationMethodParameters.qatar,
  'RU': CalculationMethodParameters.russia,
  'BN': CalculationMethodParameters.singapore,
  'MY': CalculationMethodParameters.singapore,
  'SG': CalculationMethodParameters.singapore,
  'SA': CalculationMethodParameters.ummAlQura,
  'TN': CalculationMethodParameters.tunisia,
  'TR': CalculationMethodParameters.turkiye,
};

/// Calculation parameters for a location.
///
/// The high-latitude rule is taken from adhan_dart's own recommendation
/// (seventh-of-the-night above 48°, middle-of-the-night below), and polar
/// resolution is set to `aqrabBalad` — "nearest locality" — so places where the
/// sun doesn't set still produce ordered times instead of NaN.
CalculationParameters parametersFor({
  required Coordinates coordinates,
  required String country,
}) {
  final params =
      (_methodsByCountry[country] ?? CalculationMethodParameters.muslimWorldLeague)();
  params.highLatitudeRule = HighLatitudeRule.recommended(coordinates);
  params.polarCircleResolution = PolarCircleResolution.aqrabBalad;
  return params;
}
