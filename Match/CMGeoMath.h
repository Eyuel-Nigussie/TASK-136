//
//  CMGeoMath.h
//  CourierMatch
//
//  Pure math utilities for great-circle distance (Haversine) and bounding-box
//  checks. No Core Data dependencies. See design.md section 5.2 and Q2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Great-circle distance between two lat/lng points, in miles.
/// Returns 0 if either coordinate is {0,0} (sentinel for missing data).
double CMGeoDistanceMiles(double lat1, double lng1, double lat2, double lng2);

/// Multi-leg distance: origin -> pickup -> dropoff -> destination, in miles.
double CMGeoMultiLegDistanceMiles(double originLat, double originLng,
                                  double pickupLat, double pickupLng,
                                  double dropoffLat, double dropoffLng,
                                  double destLat, double destLng);

/// Returns YES if the point (lat, lng) falls within the bounding box defined by
/// (centerLat, centerLng) expanded by radiusMiles in each direction.
BOOL CMGeoPointInBoundingBox(double lat, double lng,
                             double centerLat, double centerLng,
                             double radiusMiles);

/// Returns YES if either of the two points (lat1, lng1) or (lat2, lng2)
/// falls within the bounding box centered on (centerLat, centerLng) with
/// the given radiusMiles.
BOOL CMGeoEitherPointInBoundingBox(double lat1, double lng1,
                                   double lat2, double lng2,
                                   double centerLat, double centerLng,
                                   double radiusMiles);

/// Computes the bounding box extents around a center point.
/// Writes min/max lat/lng into the output pointers.
void CMGeoBoundingBox(double centerLat, double centerLng,
                      double radiusMiles,
                      double *outMinLat, double *outMaxLat,
                      double *outMinLng, double *outMaxLng);

NS_ASSUME_NONNULL_END
