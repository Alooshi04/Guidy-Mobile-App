import 'package:flutter/material.dart';

import '../services/banner_hide_service.dart';
import '../services/trip_pip.dart';
import 'banner_ad_placeholder.dart';

/// Turned on once the splash screen is gone. The splash is the only screen
/// without the banner.
final ValueNotifier<bool> appBannerEnabled = ValueNotifier<bool>(false);

/// True while the real banner has no ad and takes no room (not yet allowed
/// to load, no fill, offline). The screen below then keeps the status bar's
/// own padding instead of leaving a blank strip under it.
final ValueNotifier<bool> appBannerCollapsed = ValueNotifier<bool>(false);

/// One banner for the whole app, pinned to the top of every screen.
///
/// The banner sits directly under the status bar, the way Moovit does it.
/// At the bottom it sat right over the Android back/home buttons and riders
/// tapped it by mistake. Each screen used to carry its own banner; screens
/// without one (route options, lines, history, the rail map) showed no ad,
/// and every screen change threw the old ad away and loaded a new one. One
/// banner at the root never disappears and never reloads because of
/// navigation.
///
/// The banner covers the status bar's safe area, so the screens below lose
/// their top padding (their app bars, map controls and sheets start under
/// the ad, never beneath it). Their bottom padding is untouched: the system
/// navigation bar is no longer covered. The banner is hidden (but kept
/// loaded) while the keyboard is open, so text fields keep all of the space
/// above the keyboard, and while a trip is in the floating window (TripPip),
/// which is the whole app view in miniature; both give the status bar's
/// padding back to the screen.
class AppBannerShell extends StatelessWidget {
  final Widget child;

  /// What fills the slot. The real banner unless a test stands in for it
  /// (the AdMob banner only exists on a phone).
  final WidgetBuilder? bannerBuilder;

  const AppBannerShell({super.key, required this.child, this.bannerBuilder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appBannerEnabled, appBannerCollapsed, TripPip.active, BannerHideService.instance.hidden]),
      builder: (context, _) {
        // Hidden for 24 h after a rewarded ad: not built at all, so it
        // neither loads nor takes room.
        final bool enabled = appBannerEnabled.value && !BannerHideService.instance.hidden.value;
        final mq = MediaQuery.of(context);
        final bool keyboardOpen = mq.viewInsets.bottom > 0;
        final bool show = enabled && !keyboardOpen && !TripPip.active.value;
        // A test's stand-in banner always has its slot; the real one only
        // while it has an ad (or is loading one).
        final bool slotTaken = show && (bannerBuilder != null || !appBannerCollapsed.value);
        return Column(
          children: [
            if (enabled)
              Offstage(
                offstage: !show,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: bannerBuilder?.call(context) ??
                      BannerAdPlaceholder(
                        visible: show,
                        onCollapsedChanged: (c) => appBannerCollapsed.value = c,
                      ),
                ),
              ),
            Expanded(
              child: slotTaken
                  ? MediaQuery(
                      data: mq.removePadding(removeTop: true).removeViewPadding(removeTop: true),
                      child: child,
                    )
                  : child,
            ),
          ],
        );
      },
    );
  }
}
