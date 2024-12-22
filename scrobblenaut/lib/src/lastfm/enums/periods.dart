//                                                              //
// Scrobblenaut - A deadly simple Last.FM API Wrapper for Dart. //
//                  Copyright (c) 2020 Nebulino                 //
//                                                              //

part of '../../lastfm.dart';

/// List of different periods used in LastFM methods.
enum Period {
  week,
  month,
  months3,
  months6,
  year,
  overall,
}

extension PeriodExtension on Period {
  String? get value {
    switch (this) {
      case Period.week:
        return '7day';
      case Period.month:
        return '1month';
      case Period.months3:
        return '3month';
      case Period.months6:
        return '6month';
      case Period.year:
        return '12month';
      case Period.overall:
        return 'overall';
      default:
        return null;
    }
  }
}
