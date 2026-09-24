// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

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

class LocationViewer extends StatefulWidget {
  final Event event;
  final GeoUri geoUri;

  const LocationViewer(this.event, {required this.geoUri, super.key});

  @override
  LocationViewerController createState() => LocationViewerController();
}

class LocationViewerController extends State<LocationViewer> {
  static const double positionZoom = 16;

  final MapController mapController = MapController();
  Position? ownPosition;
  bool isLocating = false;

  Event get event => widget.event;

  LatLng get location =>
      LatLng(widget.geoUri.latitude, widget.geoUri.longitude);

  LatLng? get ownLocation {
    final ownPosition = this.ownPosition;
    return ownPosition == null
        ? null
        : LatLng(ownPosition.latitude, ownPosition.longitude);
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void moveToLocation() => mapController.move(location, positionZoom);

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
      UrlLauncher(context, widget.geoUri.toString()).launchUrl();

  @override
  Widget build(BuildContext context) => LocationViewerView(this);
}
