import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paints the Android navigation bar (the back/home strip at the very bottom)
/// in the app's own background for the theme in use, and gives the status
/// bar icons (clock, battery) the theme's contrast.
///
/// The status bar sits over the top banner's strip, which is the theme's
/// surface colour: white in the light theme. Left to Android, the icons
/// stayed white there and could not be seen.
///
/// Nothing in the app set it. The bar took the colour of the Android window
/// theme, which follows the phone's day/night setting, not the app's: with the
/// phone in light mode and the app in dark mode (the Settings switch), a white
/// strip showed under the dark screens.
///
/// It also keeps every screen out from under that bar. The app targets
/// Android 15+, which draws edge to edge: the bar is transparent and the app
/// window runs behind it. Flutter reports the bar's height as the bottom
/// padding but nothing pads for it by itself, and most screens (route
/// options, route detail, lists, bottom bars) have no bottom SafeArea, so
/// their last line (the "prices are estimates" note) sat behind the
/// back/home/recents buttons. The padding is applied once here, for the whole
/// app, and removed from the MediaQuery below so a screen's own SafeArea or
/// sheet doesn't pad a second time. The strip it leaves is painted in the
/// theme's background, the same colour the bar itself is given.
class SystemBarsStyle extends StatelessWidget {
  final Widget child;

  const SystemBarsStyle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final style = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      // iOS names the bar's background instead of its icons.
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarDividerColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: MediaQuery.removeViewPadding(context: context, removeBottom: true, child: child),
          ),
        ),
      ),
    );
  }
}
