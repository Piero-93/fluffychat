// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/location_viewer/location_viewer_view.dart';
import 'package:fluffychat/utils/get_current_position.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/location_content.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// A beacon and the location it was last seen at.
typedef RunningBeacon = ({Event event, GeoUri geoUri});

class LocationViewer extends StatefulWidget {
  /// The location which was tapped. For a beacon the map follows this one,
  /// while every other beacon of the room is shown as well.
  final Event event;
  final GeoUri initialGeoUri;

  /// Set for a beacon, whose location keeps coming in while it is shared.
  final Timeline? timeline;

  const LocationViewer(this.event, {required GeoUri geoUri, super.key})
    : initialGeoUri = geoUri,
      timeline = null;

  const LocationViewer.beacon(
    this.event, {
    required GeoUri geoUri,
    required Timeline this.timeline,
    super.key,
  }) : initialGeoUri = geoUri;

  bool get isBeacon => timeline != null;

  @override
  LocationViewerController createState() => LocationViewerController();
}

class LocationViewerController extends State<LocationViewer> {
  static const double positionZoom = 16;

  final MapController mapController = MapController();
  Position? ownPosition;
  bool isLocating = false;

  /// While the map follows the beacon, until the user drags it away.
  bool followsLocation = true;

  StreamSubscription<Event>? _beaconSubscription;
  Timer? _endTimer;

  Event get event => widget.event;

  bool get isBeacon => widget.isBeacon;

  bool get isRunning => isBeacon && event.isBeaconRunningAt(DateTime.now());

  /// Every beacon which is being shared in this room right now, so a group
  /// shows all of them on the same map.
  List<RunningBeacon> get beacons {
    final timeline = widget.timeline;
    if (timeline == null) return const [];
    final beacons = <RunningBeacon>[];
    for (final beaconInfo in timeline.beaconsRunningAt(DateTime.now())) {
      final beacon = beaconInfo.latestBeacon(timeline);
      final geoUri = GeoUri.tryParse(
        beacon == null ? null : getLocationGeoUri(beacon.content),
      );
      if (geoUri != null) {
        beacons.add((event: beaconInfo, geoUri: geoUri));
      }
    }
    return beacons;
  }

  /// The location the map centers on: the tapped beacon while it is running,
  /// the last known one otherwise.
  GeoUri get geoUri {
    for (final beacon in beacons) {
      if (beacon.event.eventId == event.eventId) return beacon.geoUri;
    }
    return widget.initialGeoUri;
  }

  LatLng get location => LatLng(geoUri.latitude, geoUri.longitude);

  LatLng? get ownLocation {
    final ownPosition = this.ownPosition;
    return ownPosition == null
        ? null
        : LatLng(ownPosition.latitude, ownPosition.longitude);
  }

  @override
  void initState() {
    super.initState();
    if (!isBeacon) return;
    _beaconSubscription = event.room.client.onTimelineEvent.stream.listen(
      _onTimelineEvent,
    );
    _scheduleEnd();
  }

  @override
  void dispose() {
    _beaconSubscription?.cancel();
    _endTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  void _scheduleEnd() {
    final info = BeaconInfo.parse(
      event.content,
      originServerTs: event.originServerTs,
    );
    final remaining = info.end.difference(DateTime.now());
    if (!info.live || remaining.isNegative) return;
    _endTimer = Timer(remaining, () {
      if (mounted) setState(() {});
    });
  }

  void _onTimelineEvent(Event beacon) {
    if (beacon.room.id != event.room.id) return;
    if (!BeaconEventTypes.beacon.contains(beacon.type) &&
        !BeaconEventTypes.beaconInfo.contains(beacon.type)) {
      return;
    }
    setState(() {});
    if (followsLocation) mapController.move(location, positionZoom);
  }

  void onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && followsLocation) setState(() => followsLocation = false);
  }

  void moveToLocation() {
    mapController.move(location, positionZoom);
    if (!followsLocation) setState(() => followsLocation = true);
  }

  Future<void> moveToOwnPosition() async {
    final ownLocation = this.ownLocation;
    if (ownLocation != null) {
      mapController.move(ownLocation, positionZoom);
      return;
    }
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => isLocating = true);
    try {
      final position = await getCurrentPosition();
      if (!mounted) return;
      setState(() => ownPosition = position);
      mapController.move(
        LatLng(position.latitude, position.longitude),
        positionZoom,
      );
    } on LocationUnavailableException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.reason) {
            LocationUnavailableReason.serviceDisabled =>
              l10n.locationDisabledNotice,
            LocationUnavailableReason.permissionDenied =>
              l10n.locationPermissionDeniedNotice,
          }),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorObtainingLocation(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => isLocating = false);
    }
  }

  void openInMapsAction() =>
      UrlLauncher(context, geoUri.toString()).launchUrl();

  @override
  Widget build(BuildContext context) => LocationViewerView(this);
}
