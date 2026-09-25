// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/events/map_bubble.dart';
import 'package:fluffychat/pages/location_viewer/location_viewer.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/location_content.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// The bubble of a beacon, showing its most recent location.
///
/// A beacon stops without an event of its own when the timeout runs out, so
/// the bubble schedules its own rebuild for that moment.
class LiveLocationBubble extends StatefulWidget {
  final Event event;
  final Timeline timeline;

  const LiveLocationBubble(this.event, {required this.timeline, super.key});

  @override
  State<LiveLocationBubble> createState() => _LiveLocationBubbleState();
}

class _LiveLocationBubbleState extends State<LiveLocationBubble> {
  Timer? _endTimer;

  @override
  void initState() {
    super.initState();
    _scheduleEnd();
  }

  @override
  void didUpdateWidget(LiveLocationBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleEnd();
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    super.dispose();
  }

  void _scheduleEnd() {
    _endTimer?.cancel();
    final info = BeaconInfo.parse(
      widget.event.content,
      originServerTs: widget.event.originServerTs,
    );
    final remaining = info.end.difference(DateTime.now());
    if (!info.live || remaining.isNegative) return;
    _endTimer = Timer(remaining, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final event = widget.event;
    final isRunning = event.isBeaconRunningAt(DateTime.now());

    final beacon = event.latestBeacon(widget.timeline);
    final geoUri = GeoUri.tryParse(
      beacon == null ? null : getLocationGeoUri(beacon.content),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (geoUri == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(l10n.obtainingLocation),
          )
        else
          MapBubble(
            onTap: () => showDialog(
              context: context,
              builder: (_) => LocationViewer(beacon!, geoUri: geoUri),
            ),
            latitude: geoUri.latitude,
            longitude: geoUri.longitude,
            marker: EventLocationPin(event),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRunning ? Icons.location_on : Icons.location_off,
                size: 16,
                color: isRunning ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 8),
              Text(isRunning ? l10n.liveLocation : l10n.liveLocationEnded),
            ],
          ),
        ),
      ],
    );
  }
}
