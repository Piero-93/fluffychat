// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationUnavailableReason { serviceDisabled, permissionDenied }

class LocationUnavailableException implements Exception {
  final LocationUnavailableReason reason;

  const LocationUnavailableException(this.reason);

  @override
  String toString() => 'Location unavailable: ${reason.name}';
}

/// Requests the location permission if needed and returns the current position.
///
/// Throws a [LocationUnavailableException] when the location services are
/// turned off or the permission is not granted.
Future<Position> getCurrentPosition() async {
  if (!(await Geolocator.isLocationServiceEnabled())) {
    throw const LocationUnavailableException(
      LocationUnavailableReason.serviceDisabled,
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationUnavailableException(
      LocationUnavailableReason.permissionDenied,
    );
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 30),
      ),
    );
  } on TimeoutException {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 30),
      ),
    );
  }
}
