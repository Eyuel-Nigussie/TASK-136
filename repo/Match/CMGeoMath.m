//
//  CMGeoMath.m
//  CourierMatch
//

#import "CMGeoMath.h"
#import <math.h>

/// Earth radius in miles (mean value).
static const double kEarthRadiusMiles = 3958.8;

/// Degrees to radians conversion.
static inline double toRad(double deg) {
    return deg * M_PI / 180.0;
}

double CMGeoDistanceMiles(double lat1, double lng1, double lat2, double lng2) {
    // Treat (0,0) as sentinel for missing coordinates.
    if ((lat1 == 0.0 && lng1 == 0.0) || (lat2 == 0.0 && lng2 == 0.0)) {
        return 0.0;
    }

    double dLat = toRad(lat2 - lat1);
    double dLng = toRad(lng2 - lng1);
    double rLat1 = toRad(lat1);
    double rLat2 = toRad(lat2);

    double a = sin(dLat / 2.0) * sin(dLat / 2.0)
             + cos(rLat1) * cos(rLat2) * sin(dLng / 2.0) * sin(dLng / 2.0);
    double c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));

    return kEarthRadiusMiles * c;
}

double CMGeoMultiLegDistanceMiles(double originLat, double originLng,
                                  double pickupLat, double pickupLng,
                                  double dropoffLat, double dropoffLng,
                                  double destLat, double destLng) {
    double leg1 = CMGeoDistanceMiles(originLat, originLng, pickupLat, pickupLng);
    double leg2 = CMGeoDistanceMiles(pickupLat, pickupLng, dropoffLat, dropoffLng);
    double leg3 = CMGeoDistanceMiles(dropoffLat, dropoffLng, destLat, destLng);
    return leg1 + leg2 + leg3;
}

void CMGeoBoundingBox(double centerLat, double centerLng,
                      double radiusMiles,
                      double *outMinLat, double *outMaxLat,
                      double *outMinLng, double *outMaxLng) {
    // 1 degree latitude ~ 69 miles
    double latDelta = radiusMiles / 69.0;
    // 1 degree longitude ~ 69 * cos(lat) miles
    double cosLat = cos(toRad(centerLat));
    double lngDelta = (cosLat > 0.0001) ? (radiusMiles / (69.0 * cosLat)) : 360.0;

    if (outMinLat) *outMinLat = centerLat - latDelta;
    if (outMaxLat) *outMaxLat = centerLat + latDelta;
    if (outMinLng) *outMinLng = centerLng - lngDelta;
    if (outMaxLng) *outMaxLng = centerLng + lngDelta;
}

BOOL CMGeoPointInBoundingBox(double lat, double lng,
                             double centerLat, double centerLng,
                             double radiusMiles) {
    double minLat, maxLat, minLng, maxLng;
    CMGeoBoundingBox(centerLat, centerLng, radiusMiles,
                     &minLat, &maxLat, &minLng, &maxLng);
    return (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng);
}

BOOL CMGeoEitherPointInBoundingBox(double lat1, double lng1,
                                   double lat2, double lng2,
                                   double centerLat, double centerLng,
                                   double radiusMiles) {
    double minLat, maxLat, minLng, maxLng;
    CMGeoBoundingBox(centerLat, centerLng, radiusMiles,
                     &minLat, &maxLat, &minLng, &maxLng);
    BOOL p1 = (lat1 >= minLat && lat1 <= maxLat && lng1 >= minLng && lng1 <= maxLng);
    BOOL p2 = (lat2 >= minLat && lat2 <= maxLat && lng2 >= minLng && lng2 <= maxLng);
    return (p1 || p2);
}
