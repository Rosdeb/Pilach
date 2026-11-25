import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Represents geographic coordinates (latitude and longitude).
@immutable
class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationCoordinates &&
          runtimeType == other.runtimeType &&
          (latitude - other.latitude).abs() < 0.000001 &&
          (longitude - other.longitude).abs() < 0.000001;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LocationCoordinates(lat: $latitude, lng: $longitude)';
}

/// Category of location retrieval failures.
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  missingPlugin,
  unknown,
}

/// Supported map link providers.
enum MapProvider {
  googleMaps,
  appleMaps,
  platformDefault,
}

/// The result of an attempt to fetch device coordinates.
@immutable
class LocationResult {
  final bool isSuccess;
  final LocationCoordinates? coordinates;
  final String? errorMessage;
  final LocationErrorType? errorType;

  const LocationResult._({
    required this.isSuccess,
    this.coordinates,
    this.errorMessage,
    this.errorType,
  });

  factory LocationResult.success(LocationCoordinates coordinates) {
    return LocationResult._(
      isSuccess: true,
      coordinates: coordinates,
    );
  }

  factory LocationResult.failure({
    required String errorMessage,
    required LocationErrorType errorType,
  }) {
    return LocationResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      errorType: errorType,
    );
  }

  String? get mapUrl => coordinates == null
      ? null
      : LocationService.generateMapUrl(
          latitude: coordinates!.latitude,
          longitude: coordinates!.longitude,
        );

  String? get googleMapsUrl => coordinates == null
      ? null
      : LocationService.generateGoogleMapsUrl(
          latitude: coordinates!.latitude,
          longitude: coordinates!.longitude,
        );

  String? get appleMapsUrl => coordinates == null
      ? null
      : LocationService.generateAppleMapsUrl(
          latitude: coordinates!.latitude,
          longitude: coordinates!.longitude,
        );

  String? get messageText => coordinates == null
      ? null
      : LocationService.generateLocationMessage(
          latitude: coordinates!.latitude,
          longitude: coordinates!.longitude,
        );
}

/// Service responsible for GPS coordinates retrieval, coordinate parsing,
/// and map URL formatting for location sharing in chat.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Mock hooks for unit tests
  @visibleForTesting
  static Future<bool> Function()? mockServiceEnabled;

  @visibleForTesting
  static Future<LocationPermission> Function()? mockCheckPermission;

  @visibleForTesting
  static Future<LocationPermission> Function()? mockRequestPermission;

  @visibleForTesting
  static Future<Position> Function({LocationSettings? locationSettings})? mockCurrentPosition;

  /// Regex patterns to detect Google Maps, Apple Maps, or Geo coordinates URLs
  static final RegExp _googleMapsUrlRegex = RegExp(
    r'(?:https?:\/\/)?(?:www\.)?(?:maps\.google\.com|google\.com\/maps)[^ \n]*[?&](?:q|query|ll)=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _appleMapsUrlRegex = RegExp(
    r'(?:https?:\/\/)?maps\.apple\.com[^ \n]*[?&](?:q|ll)=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _geoUriRegex = RegExp(
    r'geo:(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// Generates a universal Google Maps URL that opens directly in Maps app on iOS/Android.
  static String generateGoogleMapsUrl({
    required double latitude,
    required double longitude,
  }) {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Generates an Apple Maps URL that opens directly in Maps app on iOS/macOS.
  static String generateAppleMapsUrl({
    required double latitude,
    required double longitude,
  }) {
    return 'https://maps.apple.com/?q=$latitude,$longitude';
  }

  /// Generates a map URL based on the requested provider or device platform.
  static String generateMapUrl({
    required double latitude,
    required double longitude,
    MapProvider provider = MapProvider.platformDefault,
  }) {
    switch (provider) {
      case MapProvider.appleMaps:
        return generateAppleMapsUrl(latitude: latitude, longitude: longitude);
      case MapProvider.googleMaps:
        return generateGoogleMapsUrl(latitude: latitude, longitude: longitude);
      case MapProvider.platformDefault:
        return defaultTargetPlatform == TargetPlatform.iOS
            ? generateAppleMapsUrl(latitude: latitude, longitude: longitude)
            : generateGoogleMapsUrl(latitude: latitude, longitude: longitude);
    }
  }

  /// Generates the standard chat message text for sharing a location.
  static String generateLocationMessage({
    required double latitude,
    required double longitude,
    String? title,
    MapProvider provider = MapProvider.platformDefault,
  }) {
    final heading = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'Current Location';
    final url = generateMapUrl(
      latitude: latitude,
      longitude: longitude,
      provider: provider,
    );
    return '📍 $heading\n$url';
  }

  /// Extracts coordinates from a string containing a Maps URL or Geo URI, if present.
  static LocationCoordinates? parseCoordinates(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    final gMatch = _googleMapsUrlRegex.firstMatch(text);
    if (gMatch != null) {
      final lat = double.tryParse(gMatch.group(1) ?? '');
      final lng = double.tryParse(gMatch.group(2) ?? '');
      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        return LocationCoordinates(latitude: lat, longitude: lng);
      }
    }

    final aMatch = _appleMapsUrlRegex.firstMatch(text);
    if (aMatch != null) {
      final lat = double.tryParse(aMatch.group(1) ?? '');
      final lng = double.tryParse(aMatch.group(2) ?? '');
      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        return LocationCoordinates(latitude: lat, longitude: lng);
      }
    }

    final geoMatch = _geoUriRegex.firstMatch(text);
    if (geoMatch != null) {
      final lat = double.tryParse(geoMatch.group(1) ?? '');
      final lng = double.tryParse(geoMatch.group(2) ?? '');
      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        return LocationCoordinates(latitude: lat, longitude: lng);
      }
    }

    return null;
  }

  /// Extracts an optional label/title from a location message if present (e.g. from "📍 My Office\nhttps://...").
  static String? extractLocationTitle(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('📍')) {
        final title = trimmed.replaceFirst('📍', '').trim();
        if (title.isNotEmpty) return title;
      }
    }
    return null;
  }

  /// Validates whether a text message is a location message.
  static bool isLocationMessage(String? text) {
    if (text == null) return false;
    return parseCoordinates(text) != null;
  }

  static bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Fetches the user's current GPS position using [Geolocator].
  ///
  /// Handles service status, permissions, and timeout cleanly.
  Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 12),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final serviceEnabled = mockServiceEnabled != null
          ? await mockServiceEnabled!()
          : await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return LocationResult.failure(
          errorMessage: 'Location services are disabled on your device. Please turn on GPS.',
          errorType: LocationErrorType.serviceDisabled,
        );
      }

      LocationPermission permission = mockCheckPermission != null
          ? await mockCheckPermission!()
          : await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = mockRequestPermission != null
            ? await mockRequestPermission!()
            : await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            errorMessage: 'Location permissions were denied.',
            errorType: LocationErrorType.permissionDenied,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          errorMessage: 'Location permissions are permanently denied. Please enable them in app settings.',
          errorType: LocationErrorType.permissionDeniedForever,
        );
      }

      final position = mockCurrentPosition != null
          ? await mockCurrentPosition!(
              locationSettings: LocationSettings(
                accuracy: accuracy,
                timeLimit: timeout,
              ),
            )
          : await Geolocator.getCurrentPosition(
              locationSettings: LocationSettings(
                accuracy: accuracy,
                timeLimit: timeout,
              ),
            );

      return LocationResult.success(
        LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on TimeoutException {
      return LocationResult.failure(
        errorMessage: 'Timed out while acquiring GPS location.',
        errorType: LocationErrorType.timeout,
      );
    } on MissingPluginException {
      debugPrint('[LocationService] MissingPluginException: Native geolocator plugin not compiled into running binary.');
      return LocationResult.failure(
        errorMessage: 'Location plugin requires a fresh app rebuild. Please stop the app and run it again.',
        errorType: LocationErrorType.missingPlugin,
      );
    } on PlatformException catch (pe) {
      debugPrint('[LocationService] PlatformException: ${pe.code} - ${pe.message}');
      return LocationResult.failure(
        errorMessage: pe.message ?? 'Location services error on device.',
        errorType: LocationErrorType.unknown,
      );
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      return LocationResult.failure(
        errorMessage: 'Failed to retrieve location: $e',
        errorType: LocationErrorType.unknown,
      );
    }
  }
}
