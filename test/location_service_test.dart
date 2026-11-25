import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/core/services/location_service.dart';

void main() {
  setUp(() {
    LocationService.mockServiceEnabled = null;
    LocationService.mockCheckPermission = null;
    LocationService.mockRequestPermission = null;
    LocationService.mockCurrentPosition = null;
  });

  tearDown(() {
    LocationService.mockServiceEnabled = null;
    LocationService.mockCheckPermission = null;
    LocationService.mockRequestPermission = null;
    LocationService.mockCurrentPosition = null;
  });

  group('LocationService - URL and Message Formatting', () {
    test('generateGoogleMapsUrl produces standard coordinate URL', () {
      final url = LocationService.generateGoogleMapsUrl(
        latitude: 23.8103,
        longitude: 90.4125,
      );
      expect(url, equals('https://maps.google.com/?q=23.8103,90.4125'));
    });

    test('generateAppleMapsUrl produces standard Apple Maps coordinate URL', () {
      final url = LocationService.generateAppleMapsUrl(
        latitude: 37.7749,
        longitude: -122.4194,
      );
      expect(url, equals('https://maps.apple.com/?q=37.7749,-122.4194'));
    });

    test('generateMapUrl returns requested provider URL', () {
      final gUrl = LocationService.generateMapUrl(
        latitude: 23.8,
        longitude: 90.4,
        provider: MapProvider.googleMaps,
      );
      expect(gUrl, contains('maps.google.com'));

      final aUrl = LocationService.generateMapUrl(
        latitude: 23.8,
        longitude: 90.4,
        provider: MapProvider.appleMaps,
      );
      expect(aUrl, contains('maps.apple.com'));
    });

    test('generateGoogleMapsUrl supports negative coordinates', () {
      final url = LocationService.generateGoogleMapsUrl(
        latitude: -33.8688,
        longitude: 151.2093,
      );
      expect(url, equals('https://maps.google.com/?q=-33.8688,151.2093'));
    });

    test('generateLocationMessage produces default heading when title omitted', () {
      final msg = LocationService.generateLocationMessage(
        latitude: 23.8103,
        longitude: 90.4125,
        provider: MapProvider.googleMaps,
      );
      expect(msg, contains('📍 Current Location'));
      expect(msg, contains('https://maps.google.com/?q=23.8103,90.4125'));
    });

    test('generateLocationMessage produces Apple Maps link when appleMaps provider specified', () {
      final msg = LocationService.generateLocationMessage(
        latitude: 37.7749,
        longitude: -122.4194,
        provider: MapProvider.appleMaps,
      );
      expect(msg, contains('📍 Current Location'));
      expect(msg, contains('https://maps.apple.com/?q=37.7749,-122.4194'));
    });

    test('generateLocationMessage uses custom title when provided', () {
      final msg = LocationService.generateLocationMessage(
        latitude: 40.7128,
        longitude: -74.0060,
        title: 'Central Park Meeting Point',
        provider: MapProvider.googleMaps,
      );
      expect(msg, contains('📍 Central Park Meeting Point'));
      expect(msg, contains('https://maps.google.com/?q=40.7128,-74.006'));
    });
  });

  group('LocationService - Coordinate Extraction and Detection', () {
    test('parseCoordinates extracts from Google Maps ?q= URL', () {
      const text = 'Check out where I am:\nhttps://maps.google.com/?q=23.8103,90.4125';
      final coords = LocationService.parseCoordinates(text);
      expect(coords, isNotNull);
      expect(coords!.latitude, closeTo(23.8103, 0.0001));
      expect(coords.longitude, closeTo(90.4125, 0.0001));
    });

    test('parseCoordinates extracts from Google Maps query= URL', () {
      const text = 'https://www.google.com/maps?query=-33.8688,151.2093';
      final coords = LocationService.parseCoordinates(text);
      expect(coords, isNotNull);
      expect(coords!.latitude, closeTo(-33.8688, 0.0001));
      expect(coords.longitude, closeTo(151.2093, 0.0001));
    });

    test('parseCoordinates extracts from Apple Maps ?q= URL', () {
      const text = 'Shared from iPhone: https://maps.apple.com/?q=37.7749,-122.4194';
      final coords = LocationService.parseCoordinates(text);
      expect(coords, isNotNull);
      expect(coords!.latitude, closeTo(37.7749, 0.0001));
      expect(coords.longitude, closeTo(-122.4194, 0.0001));
    });

    test('parseCoordinates extracts from geo: URI', () {
      const text = 'geo:51.5074,-0.1278';
      final coords = LocationService.parseCoordinates(text);
      expect(coords, isNotNull);
      expect(coords!.latitude, closeTo(51.5074, 0.0001));
      expect(coords.longitude, closeTo(-0.1278, 0.0001));
    });

    test('parseCoordinates rejects invalid out-of-range coordinates', () {
      const invalidLat = 'https://maps.google.com/?q=999.0,50.0';
      const invalidLng = 'https://maps.google.com/?q=45.0,999.0';
      expect(LocationService.parseCoordinates(invalidLat), isNull);
      expect(LocationService.parseCoordinates(invalidLng), isNull);
    });

    test('parseCoordinates returns null for non-map URLs or plain text', () {
      expect(LocationService.parseCoordinates('Hello world'), isNull);
      expect(LocationService.parseCoordinates('https://google.com'), isNull);
      expect(LocationService.parseCoordinates(''), isNull);
      expect(LocationService.parseCoordinates(null), isNull);
    });

    test('isLocationMessage correctly identifies messages', () {
      expect(LocationService.isLocationMessage('https://maps.google.com/?q=23.8,90.4'), isTrue);
      expect(LocationService.isLocationMessage('Hello there!'), isFalse);
    });

    test('extractLocationTitle extracts title line from formatted message', () {
      const msg = '📍 My Home Office\nhttps://maps.google.com/?q=23.8,90.4';
      expect(LocationService.extractLocationTitle(msg), equals('My Home Office'));
      expect(LocationService.extractLocationTitle('Just a link: https://maps.google.com/?q=1,1'), isNull);
    });
  });

  group('LocationService - GPS Retrieval Flow', () {
    test('returns failure when location service is disabled', () async {
      LocationService.mockServiceEnabled = () async => false;

      final result = await LocationService.instance.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(LocationErrorType.serviceDisabled));
      expect(result.errorMessage, contains('GPS'));
    });

    test('returns failure when permission is denied and not granted on request', () async {
      LocationService.mockServiceEnabled = () async => true;
      LocationService.mockCheckPermission = () async => LocationPermission.denied;
      LocationService.mockRequestPermission = () async => LocationPermission.denied;

      final result = await LocationService.instance.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(LocationErrorType.permissionDenied));
    });

    test('returns failure when permission is denied forever', () async {
      LocationService.mockServiceEnabled = () async => true;
      LocationService.mockCheckPermission = () async => LocationPermission.deniedForever;

      final result = await LocationService.instance.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(LocationErrorType.permissionDeniedForever));
      expect(result.errorMessage, contains('settings'));
    });

    test('returns failure on MissingPluginException when app is not rebuilt', () async {
      LocationService.mockServiceEnabled = () async {
        throw MissingPluginException();
      };

      final result = await LocationService.instance.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(LocationErrorType.missingPlugin));
      expect(result.errorMessage, contains('rebuild'));
    });

    test('returns failure on timeout', () async {
      LocationService.mockServiceEnabled = () async => true;
      LocationService.mockCheckPermission = () async => LocationPermission.always;
      LocationService.mockCurrentPosition = ({LocationSettings? locationSettings}) async {
        throw TimeoutException('GPS timed out');
      };

      final result = await LocationService.instance.getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(LocationErrorType.timeout));
    });

    test('returns success with coordinates when granted and acquired', () async {
      LocationService.mockServiceEnabled = () async => true;
      LocationService.mockCheckPermission = () async => LocationPermission.whileInUse;
      LocationService.mockCurrentPosition = ({LocationSettings? locationSettings}) async {
        return Position(
          longitude: 90.4125,
          latitude: 23.8103,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      };

      final result = await LocationService.instance.getCurrentLocation();
      expect(result.isSuccess, isTrue);
      expect(result.coordinates, isNotNull);
      expect(result.coordinates!.latitude, closeTo(23.8103, 0.0001));
      expect(result.coordinates!.longitude, closeTo(90.4125, 0.0001));
      expect(result.mapUrl, equals('https://maps.google.com/?q=23.8103,90.4125'));
      expect(result.messageText, contains('📍 Current Location'));
    });
  });
}
