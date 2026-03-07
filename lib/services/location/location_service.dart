import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Lightweight data class holding a resolved location.
class LocationData {
  const LocationData({
    required this.latitude,
    required this.longitude,
    this.locationName,
  });

  final double latitude;
  final double longitude;

  /// Human-readable location such as "Brooklyn, NY".
  final String? locationName;

  @override
  String toString() =>
      'LocationData(lat: $latitude, lng: $longitude, name: $locationName)';
}

/// Service for obtaining the device's current location and reverse-geocoding
/// it into a human-readable name.
class LocationService {
  LocationService._internal();

  static final LocationService _instance = LocationService._internal();

  /// Singleton accessor.
  static LocationService get instance => _instance;

  factory LocationService() => _instance;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests location permission from the user.
  ///
  /// Returns `true` if permission is granted (either already or after the
  /// request), `false` otherwise.
  Future<bool> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          debugPrint('[LocationService] Location services are disabled.');
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            debugPrint('[LocationService] Permission denied by user.');
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          debugPrint('[LocationService] Permission permanently denied.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationService] Error requesting permission: $e');
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Position
  // ---------------------------------------------------------------------------

  /// Returns the device's current position, or `null` if unavailable.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationService] Error getting position: $e');
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Reverse geocoding
  // ---------------------------------------------------------------------------

  /// Reverse-geocodes [lat]/[lng] into a short human-readable name such as
  /// "Brooklyn, NY". Returns `null` on failure.
  Future<String?> getLocationName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;

      // Build a concise "Locality, AdminArea" string.
      final parts = <String>[
        if (place.locality != null && place.locality!.isNotEmpty)
          place.locality!
        else if (place.subLocality != null && place.subLocality!.isNotEmpty)
          place.subLocality!,
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty)
          place.administrativeArea!,
      ];

      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationService] Reverse geocoding failed: $e');
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Combined convenience method
  // ---------------------------------------------------------------------------

  /// Obtains the current position and resolves it to a [LocationData] object
  /// that includes latitude, longitude, and a human-readable name.
  ///
  /// Returns `null` if the position cannot be determined.
  Future<LocationData?> getCurrentLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final name = await getLocationName(position.latitude, position.longitude);

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      locationName: name,
    );
  }
}
