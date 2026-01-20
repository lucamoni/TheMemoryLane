import 'dart:math' as math;

class GeoUtils {
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  static double getTotalDistance(List<List<double>> gpsTrack) {
    if (gpsTrack.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < gpsTrack.length - 1; i++) {
      total += calculateDistance(
        gpsTrack[i][0],
        gpsTrack[i][1],
        gpsTrack[i + 1][0],
        gpsTrack[i + 1][1],
      );
    }
    return total;
  }

  static List<List<double>> simplifyTrack(List<List<double>> track, double tolerance) {
    if (track.length <= 2) return track;

    List<List<double>> simplified = [track[0]];

    for (int i = 1; i < track.length - 1; i++) {
      final double distance = _distanceFromPointToLine(
        track[i],
        track[i - 1],
        track[i + 1],
      );

      if (distance > tolerance) {
        simplified.add(track[i]);
      }
    }

    simplified.add(track[track.length - 1]);
    return simplified;
  }

  static double _distanceFromPointToLine(
      List<double> point, List<double> lineStart, List<double> lineEnd) {
    final double px = point[0];
    final double py = point[1];
    final double x1 = lineStart[0];
    final double y1 = lineStart[1];
    final double x2 = lineEnd[0];
    final double y2 = lineEnd[1];

    final double numerator = ((y2 - y1) * px - (x2 - x1) * py + x2 * y1 - y2 * x1).abs();
    final double denominator = math.sqrt((y2 - y1) * (y2 - y1) + (x2 - x1) * (x2 - x1));

    return numerator / denominator;
  }
}


