import 'dart:async';

import 'package:flutter/material.dart';
import 'HomeScreen.dart';
import 'LinesScreen.dart';
import 'MetroScreen.dart';
import 'HistoryScreen.dart';
import 'SettingsScreen.dart';
import '../services/whats_new.dart';
import '../services/trip_history_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../services/notification_permission.dart';
import '../services/simple_mode.dart';
import '../services/tour_service.dart';
import '../widgets/app_banner_shell.dart';
import '../widgets/guidy_tour.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(2);

  static void goToTab(int index) {
    activeTabNotifier.value = index;
    if (index == 3 || index == 2) {
      TripHistoryService.changeNotifier.value++;
    }
  }

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 2; // Home in the center by default
  final LinesBackController _linesBack = LinesBackController();
  final ScrollController _settingsScroll = ScrollController();
  // One per tab (Settings uses its own, above), so a tab can be put back
  // at the top when another one is chosen.
  final List<ScrollController> _tabScrolls = List.generate(4, (_) => ScrollController());

  // ------------------------------------------------------------ app tour
  final HomeTourKeys _homeKeys = HomeTourKeys();
  final List<GlobalKey> _tabKeys = List.generate(5, (i) => GlobalKey(debugLabel: 'tour_tab_$i'));
  bool _touring = false;

  /// MainNavigators in the tree (one, except for a frame while signing
  /// out and back in swaps them).
  static int _mounted = 0;

  @override
  void initState() {
    super.initState();
    // The top banner shows only over the app itself, never over the
    // sign-in, loading, verification or consent screens before it (AdMob
    // placement policy). After this frame: the shell is building now.
    _mounted++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted > 0) appBannerEnabled.value = true;
    });
    MainNavigator.activeTabNotifier.addListener(_onTabNotification);
    TourService.replayRequests.addListener(_onReplayTour);
    if (GuidyTour.autoStart) {
      // After the first frames, so Home is laid out and the tour can find
      // what it points at.
      Future.delayed(const Duration(milliseconds: 900), _maybeStartTour);
    }
  }

  Future<void> _maybeStartTour() async {
    if (!mounted || _selectedIndex != 2 || !GuidyTour.isOnTop(context)) return;
    // The notification permission, once ever, before any tour or news.
    await NotificationPermission.askOnce();
    if (!mounted || !GuidyTour.isOnTop(context)) return;
    // A rider who has had the tour is updating: show them what changed. A
    // new rider gets the tour instead (and only the build is remembered).
    if (await TourService.hasSeen(TourService.home)) {
      final news = await WhatsNew.takeForLaunch(freshInstall: false);
      if (news != null && mounted && GuidyTour.isOnTop(context)) await _showWhatsNew(news);
      return;
    }
    unawaited(WhatsNew.takeForLaunch(freshInstall: true));
    // Simple mode is turned on in Settings only, and has no tour.
    if (!mounted || simpleMode.value || !GuidyTour.isOnTop(context)) return;
    await _runTour();
  }

  /// "What's new", once, on the first launch after an update.
  Future<void> _showWhatsNew(WhatsNewEntry news) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('whats_new'),
        title: Text(l10n.whatsNewTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final note in news.popupNotesFor(l10n.localeName))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 16, height: 1.4)),
                    Expanded(child: Text(note, style: const TextStyle(fontSize: 16, height: 1.4))),
                  ],
                ),
              ),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.whatsNewOk)),
        ],
      ),
    );
  }

  void _onReplayTour() {
    if (simpleMode.value) return;
    MainNavigator.goToTab(2);
    Future.delayed(const Duration(milliseconds: 500), _runTour);
  }

  /// Home's main features, then each tab. Seen once finished or skipped.
  Future<void> _runTour() async {
    if (!mounted || _touring) return;
    _touring = true;
    final l10n = AppLocalizations.of(context);
    await GuidyTour.show(context, [
      TourStep(title: l10n.tourWelcomeTitle, body: l10n.tourWelcomeBody),
      TourStep(target: _homeKeys.search, title: l10n.tourSearchTitle, body: l10n.tourSearchBody),
      TourStep(target: _homeKeys.quick, title: l10n.tourQuickTitle, body: l10n.tourQuickBody),
      TourStep(target: _homeKeys.recent, title: l10n.tourRecentTitle, body: l10n.tourRecentBody),
      TourStep(target: _tabKeys[0], title: l10n.tourLinesTitle, body: l10n.tourLinesBody),
      TourStep(target: _tabKeys[1], title: l10n.tourMetroTitle, body: l10n.tourMetroBody),
      TourStep(target: _tabKeys[3], title: l10n.tourTripsTitle, body: l10n.tourTripsBody),
      TourStep(target: _tabKeys[4], title: l10n.tourSettingsTitle, body: l10n.tourSettingsBody),
    ]);
    await TourService.markSeen(TourService.home);
    _touring = false;
  }

  @override
  void dispose() {
    _mounted--;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted == 0) appBannerEnabled.value = false;
    });
    TourService.replayRequests.removeListener(_onReplayTour);
    MainNavigator.activeTabNotifier.removeListener(_onTabNotification);
    _settingsScroll.dispose();
    for (final c in _tabScrolls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabNotification() {
    final index = MainNavigator.activeTabNotifier.value;
    if (mounted && _selectedIndex != index) {
      _resetScroll(_selectedIndex);
      setState(() => _selectedIndex = index);
    }
    // Settings keeps its scroll in the IndexedStack, so it is put back at
    // the top each time it is chosen, same as before.
    if (index == 4 && _settingsScroll.hasClients) _settingsScroll.jumpTo(0);
  }

  /// A tab left behind comes back at the top. An open Lines mode stays open
  /// (the rider chose it); only its scroll resets.
  void _resetScroll(int tab) {
    final c = tab == 4 ? _settingsScroll : _tabScrolls[tab];
    if (c.hasClients) c.jumpTo(0);
    if (tab == 0) _linesBack.scrollToTop();
  }

  void _goToHome() {
    MainNavigator.goToTab(2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget scrolls(int i, Widget tab) => PrimaryScrollController(controller: _tabScrolls[i], child: tab);
    final List<Widget> tabs = [
      scrolls(0, LinesScreen(onGoHome: _goToHome, backController: _linesBack)),
      scrolls(1, MetroScreen(onGoHome: _goToHome)),
      scrolls(2, HomeScreen(tourKeys: _homeKeys)), // Middle / Main Menu!
      scrolls(3, HistoryScreen(onGoHome: _goToHome)),
      SettingsScreen(onGoHome: _goToHome, scrollController: _settingsScroll),
    ];

    return PopScope(
      canPop: _selectedIndex == 2,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _selectedIndex == 2) return;
        // Inside a Lines mode list, back first returns to the tile grid.
        if (_selectedIndex == 0 && _linesBack.handleBack()) return;
        _goToHome();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _selectedIndex, children: tabs),
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: simpleMode,
          builder: (context, simple, _) {
            // Tab icons are the ones drawn in the Figma design, tinted
            // brand blue when selected and the design's pale grey otherwise.
            // Labels use the darker muted text colour so they stay readable.
            final inactive = context.isDark ? context.textSecondary : GuidyUi.tabInactive;
            final inactiveLabel = GuidyUi.mutedText(context);
            NavigationDestination tab(int index, String icon, String label) => NavigationDestination(
                  key: _tabKeys[index],
                  icon: GuidySvgIcon(icon, size: 24, color: inactive),
                  selectedIcon: GuidySvgIcon(icon, size: 24, color: AppColors.brandBlue),
                  label: label,
                );
            final all = <NavigationDestination>[
              tab(0, 'tab_lines', l10n.navLines),
              tab(1, 'tab_metro', l10n.navMetro),
              tab(2, 'tab_home', l10n.navHome),
              tab(3, 'tab_trips', l10n.navHistory),
              tab(4, 'tab_settings', l10n.navSettings),
            ];
            // Simple mode keeps Home, History and Settings only; the tab
            // numbers used everywhere else (goToTab) stay the same.
            final visible = simple ? const [2, 3, 4] : const [0, 1, 2, 3, 4];
            final pos = visible.indexOf(_selectedIndex);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(GuidyUi.radius)),
                boxShadow: [
                  BoxShadow(
                    color: context.isDark ? Colors.black.withValues(alpha: 0.35) : AppColors.brandNavy.withValues(alpha: 0.20),
                    blurRadius: 5.8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                          fontSize: 12,
                          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
                          color: states.contains(WidgetState.selected) ? AppColors.brandBlue : inactiveLabel,
                        )),
                  ),
                  child: NavigationBar(
                    height: simple ? 80 : 68,
                    selectedIndex: pos < 0 ? visible.indexOf(2) : pos,
                    onDestinationSelected: (i) => MainNavigator.goToTab(visible[i]),
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor: Colors.transparent,
                    animationDuration: const Duration(milliseconds: 220),
                    destinations: [for (final i in visible) all[i]],
                  ),
                ),
            );
          },
        ),
      ),
    );
  }
}
