import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class CapturedSurveyLocation {
  const CapturedSurveyLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final String label;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}

class DeviceLocationService {
  Future<CapturedSurveyLocation> captureCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are turned off on this device. Please enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission was denied. Please allow location access to start a survey.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Please enable it from app settings.',
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null) {
      return CapturedSurveyLocation(
        label: 'Location not captured',
        latitude: 0.0,
        longitude: 0.0,
        accuracyMeters: 0.0,
        capturedAt: DateTime.now(),
      );
    }

    final label = await _resolveLabel(position);
    return CapturedSurveyLocation(
      label: label,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: DateTime.now(),
    );
  }

  Future<String> _resolveLabel(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return _fallbackLabel(position.latitude, position.longitude);
      }

      final placemark = placemarks.first;
      final parts = [
        placemark.subLocality,
        placemark.locality,
        placemark.administrativeArea,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();

      if (parts.isEmpty) {
        return _fallbackLabel(position.latitude, position.longitude);
      }

      return parts.join(', ');
    } catch (_) {
      return _fallbackLabel(position.latitude, position.longitude);
    }
  }

  String _fallbackLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}
