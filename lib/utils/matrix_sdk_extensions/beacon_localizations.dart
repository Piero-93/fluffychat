// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/matrix_sdk_extensions/location_content.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:matrix/matrix.dart';

/// Teaches the sdk to describe the beacon events of MSC3672, which it does not
/// know, so chat previews and notifications do not fall back to the event type.
///
/// This also makes them count as known events, which the option to hide unknown
/// events relies on.
void registerBeaconLocalizations() {
  for (final type in {
    ...BeaconEventTypes.beaconInfo,
    ...BeaconEventTypes.beacon,
  }) {
    EventLocalizations.localizationsMap[type] = (event, i18n, body) =>
        i18n is MatrixLocals
        ? i18n.l10n.sharedALiveLocation(
            event.senderFromMemoryOrFallback.calcDisplayname(i18n: i18n),
          )
        : body;
  }
}
