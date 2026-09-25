// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

/// Content keys and asset types as described in MSC3488:
/// https://github.com/matrix-org/matrix-spec-proposals/pull/3488
abstract class LocationContentKeys {
  static const String location = 'org.matrix.msc3488.location';
  static const String asset = 'org.matrix.msc3488.asset';
  static const String timestamp = 'org.matrix.msc3488.ts';
}

abstract class LocationAssetTypes {
  static const String self = 'm.self';
  static const String pin = 'm.pin';
}

class GeoUri {
  final double latitude;
  final double longitude;
  final double? uncertainty;

  const GeoUri({
    required this.latitude,
    required this.longitude,
    this.uncertainty,
  });

  static GeoUri? tryParse(String? uriString) {
    if (uriString == null) return null;
    final uri = Uri.tryParse(uriString);
    if (uri == null || uri.scheme != 'geo') return null;

    final [coordinates, ...parameters] = uri.path.split(';');
    final latlong = coordinates.split(',').map(double.tryParse).toList();
    if (latlong.length < 2 || latlong.length > 3) return null;
    final latitude = latlong.first;
    final longitude = latlong[1];
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;

    double? uncertainty;
    for (final parameter in parameters) {
      final [key, ...value] = parameter.split('=');
      if (key.toLowerCase() == 'u') uncertainty = double.tryParse(value.join());
    }

    return GeoUri(
      latitude: latitude,
      longitude: longitude,
      uncertainty: uncertainty,
    );
  }

  @override
  String toString() => uncertainty == null
      ? 'geo:$latitude,$longitude'
      : 'geo:$latitude,$longitude;u=$uncertainty';
}

String? getLocationGeoUri(Map<String, Object?> content) =>
    content.tryGet<String>('geo_uri') ??
    content
        .tryGetMap<String, Object?>(LocationContentKeys.location)
        ?.tryGet<String>('uri');

/// MSC3488 defines `m.self` as default when no asset type is given.
String getLocationAssetType(Map<String, Object?> content) =>
    content
        .tryGetMap<String, Object?>(LocationContentKeys.asset)
        ?.tryGet<String>('type') ??
    LocationAssetTypes.self;

Map<String, Object?> buildLocationContent({
  required GeoUri geoUri,
  required String assetType,
  required DateTime timestamp,
}) {
  final uri = geoUri.toString();
  return {
    'msgtype': MessageTypes.Location,
    'body':
        'https://www.openstreetmap.org/?mlat=${geoUri.latitude}&mlon=${geoUri.longitude}#map=16/${geoUri.latitude}/${geoUri.longitude}',
    'geo_uri': uri,
    LocationContentKeys.location: {'uri': uri},
    LocationContentKeys.asset: {'type': assetType},
    LocationContentKeys.timestamp: timestamp.millisecondsSinceEpoch,
  };
}

/// Event types and content keys as described in MSC3672:
/// https://github.com/matrix-org/matrix-spec-proposals/pull/3672
abstract class BeaconEventTypes {
  static const Set<String> beaconInfo = {
    'm.beacon_info',
    'org.matrix.msc3672.beacon_info',
  };
  static const Set<String> beacon = {'m.beacon', 'org.matrix.msc3672.beacon'};
}

class BeaconInfo {
  final bool live;
  final Duration timeout;
  final DateTime start;

  const BeaconInfo({
    required this.live,
    required this.timeout,
    required this.start,
  });

  DateTime get end => start.add(timeout);

  bool isRunningAt(DateTime time) => live && time.isBefore(end);

  /// The `live` and `timeout` keys are top level in the content, while the
  /// start is the MSC3488 timestamp, which falls back to the event timestamp.
  static BeaconInfo parse(
    Map<String, Object?> content, {
    required DateTime originServerTs,
  }) {
    final timestamp = content.tryGet<int>(LocationContentKeys.timestamp);
    return BeaconInfo(
      live: content.tryGet<bool>('live') ?? false,
      timeout: Duration(milliseconds: content.tryGet<int>('timeout') ?? 0),
      start: timestamp == null
          ? originServerTs
          : DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

extension BeaconEventExtension on Event {
  /// The MSC3488 timestamp, falling back to the timestamp of the event itself.
  DateTime get locationTimestamp {
    final timestamp = content.tryGet<int>(LocationContentKeys.timestamp);
    return timestamp == null
        ? originServerTs
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// The most recent location of this beacon. Updates from anyone but the
  /// sender of the beacon are ignored, as everybody may send an event
  /// referencing it.
  Event? latestBeacon(Timeline timeline) {
    Event? latest;
    for (final event in aggregatedEvents(
      timeline,
      RelationshipTypes.reference,
    )) {
      if (!BeaconEventTypes.beacon.contains(event.type)) continue;
      if (event.senderId != senderId) continue;
      if (latest == null ||
          event.locationTimestamp.isAfter(latest.locationTimestamp)) {
        latest = event;
      }
    }
    return latest;
  }

  /// Whether this beacon is still sharing at [time].
  ///
  /// Sharing ends when the timeout runs out, when the sender turns it off and
  /// when they start a newer one, as a beacon is a state event per user and
  /// only the current state counts.
  bool isBeaconRunningAt(DateTime time) {
    final info = BeaconInfo.parse(content, originServerTs: originServerTs);
    if (!info.isRunningAt(time)) return false;
    final currentState = room.getState(type, stateKey ?? '');
    if (currentState == null) return true;
    final currentInfo = BeaconInfo.parse(
      currentState.content,
      originServerTs: originServerTs,
    );
    if (currentInfo.start.isAfter(info.start)) return false;
    return currentInfo.live;
  }
}
