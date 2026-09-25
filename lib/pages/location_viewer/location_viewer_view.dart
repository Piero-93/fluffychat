// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/map_bubble.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';

import 'location_viewer.dart';

class LocationViewerView extends StatelessWidget {
  final LocationViewerController controller;

  const LocationViewerView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final ownLocation = controller.ownLocation;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: Navigator.of(context).pop,
          tooltip: l10n.close,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(controller.event.senderFromMemoryOrFallback.calcDisplayname()),
            if (controller.isBeacon)
              Text(
                controller.isRunning
                    ? l10n.liveLocation
                    : l10n.liveLocationEnded,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_outlined),
            onPressed: controller.openInMapsAction,
            tooltip: l10n.openInMaps,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialCenter: controller.location,
              initialZoom: LocationViewerController.positionZoom,
              onPositionChanged: controller.onPositionChanged,
            ),
            children: [
              const OpenStreetMapTileLayer(),
              MarkerLayer(
                rotate: true,
                markers: [
                  if (ownLocation != null)
                    Marker(
                      point: ownLocation,
                      width: OwnPositionMarker.size,
                      height: OwnPositionMarker.size,
                      child: const OwnPositionMarker(),
                    ),
                  Marker(
                    point: controller.location,
                    width: LocationPin.size,
                    height: LocationPin.size,
                    child: EventLocationPin(controller.event),
                  ),
                ],
              ),
            ],
          ),
          const OpenStreetMapAttribution(),
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                IconButton.filledTonal(
                  tooltip: l10n.myLocation,
                  onPressed: controller.isLocating
                      ? null
                      : controller.moveToOwnPosition,
                  icon: controller.isLocating
                      ? const CupertinoActivityIndicator()
                      : const Icon(Icons.my_location_outlined),
                ),
                const SizedBox(height: 8),
                IconButton.filledTonal(
                  tooltip: l10n.showLocation,
                  onPressed: controller.followsLocation
                      ? null
                      : controller.moveToLocation,
                  icon: const Icon(Icons.location_pin),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
