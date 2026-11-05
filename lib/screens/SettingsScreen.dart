import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import 'PatchNotesScreen.dart';
import '../services/tour_service.dart';
import '../services/locale_controller.dart';
import '../services/theme_controller.dart';
import '../services/analytics_service.dart';
import '../services/review_service.dart';
import '../services/account_service.dart';
import '../services/social_auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../services/simple_mode.dart';
import '../widgets/simple/simple_ui.dart';
import '../services/commute/commute_notifications.dart';
import '../services/commute/commute_store.dart';
import '../services/consent_service.dart';
import '../widgets/hide_banner_tile.dart';
import '../services/trip_sharing.dart';
import '../widgets/change_password_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onGoHome;

  /// MainNavigator's, so it can open Settings at the top each time.
  final ScrollController? scrollController;
  const SettingsScreen({super.key, this.onGoHome, this.scrollController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  // Back from the phone's settings: the notifications switch may have moved.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotificationsAllowed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const String _contactEmail = 'info@guidyapp.com';

  // Read from the installed build, so it follows pubspec's version on every
  // update instead of a number typed here.
  String _version = '';

  @override
  void initState() {
    super.initState();
    CommuteStore.loadSettings();
    CommuteStore.loadLines().then((saved) {
      if (mounted) setState(() => _commuteHasLines = saved.lines.isNotEmpty);
    });
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationsAllowed();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _version = 'v${info.version} (${info.buildNumber})');
    }).catchError((_) {});
  }

  Future<void> _launchContactEmail(AppLocalizations l10n) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': 'Guidy: '},
    );
    final launched = await launchUrl(emailUri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_contactEmail)),
      );
    }
  }

  Future<void> _confirmAndDeleteAccount(AppLocalizations l10n, {required bool isGuest}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isGuest ? l10n.deleteGuestDataConfirmTitle : l10n.deleteAccountConfirmTitle),
        content: Text(isGuest ? l10n.deleteGuestDataConfirmBody : l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteButton, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await AccountService.deleteAccount();

    if (result.success) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (!mounted) return;

    if (result.needsReauth) {
      await _reauthenticateAndRetryDelete(l10n);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed), backgroundColor: Colors.red),
      );
    }
  }

  /// Firebase requires a *recent* login before it'll delete an account --
  /// see account_service.dart. This re-authenticates using whichever
  /// provider the person originally signed in with, then retries the
  /// deletion once, and surfaces a plain failure message if that also
  /// doesn't work (e.g. they cancel the picker, or a second reauth
  /// attempt is still somehow not "recent" enough).
  Future<void> _reauthenticateAndRetryDelete(AppLocalizations l10n) async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final providerIds = user.providerData.map((p) => p.providerId).toSet();

    AuthCredential? credential;

    if (providerIds.contains('password')) {
      final password = await _promptForPassword(l10n);
      if (password == null || !mounted) return; // cancelled
      credential = EmailAuthProvider.credential(email: user.email!, password: password);
    } else if (providerIds.contains('google.com')) {
      credential = await SocialAuthService.getGoogleCredential();
    }
    // Anonymous/guest accounts have no provider to reauthenticate with --
    // deleteAccount() above should already have succeeded directly for
    // them without ever reaching this method.

    if (credential == null) return; // person cancelled the reauth step
    if (!mounted) return;

    final result = await AccountService.reauthenticateAndDelete(credential);
    if (result.success) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _promptForPassword(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reauthRequiredTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.reauthRequiredBody),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.passwordHint),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.confirmButton),
          ),
        ],
      ),
    );
    return (password == null || password.isEmpty) ? null : password;
  }

  void _showLanguagePicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.languageSwitcherTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                title: Text(l10n.languageEnglish),
                trailing: !localeController.isArabic ? const Icon(Icons.check, color: AppColors.primaryTeal) : null,
                onTap: () {
                  Navigator.pop(context);
                  localeController.setLocale(LocaleController.english);
                  AnalyticsService.logLanguageChanged('en');
                },
              ),
              ListTile(
                title: Text(l10n.languageArabic),
                trailing: localeController.isArabic ? const Icon(Icons.check, color: AppColors.primaryTeal) : null,
                onTap: () {
                  Navigator.pop(context);
                  localeController.setLocale(LocaleController.egyptianArabic);
                  AnalyticsService.logLanguageChanged('ar');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// "Share my trips": the one switch for what Guidy records of a trip
  /// (vehicle route and GPS, walking paths). On by default, as the Terms
  /// say; the info button says what it covers.
  Widget _tripSharing(BuildContext context, AppLocalizations l10n) {
    void explain() => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            key: const ValueKey('trip-sharing-info-dialog'),
            title: Text(l10n.tripSharingInfoTitle),
            content: SingleChildScrollView(child: Text(l10n.tripSharingInfoBody, style: const TextStyle(height: 1.4))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.tripSharingInfoOk))],
          ),
        );

    return ValueListenableBuilder<bool>(
      valueListenable: TripSharing.enabled,
      builder: (context, on, _) => ListTile(
        leading: Icon(Icons.route_outlined, color: context.textSecondary),
        title: _rowTitle(l10n.tripSharingLabel),
        subtitle: Text(l10n.tripSharingSubtitle, style: TextStyle(color: context.textSecondary, fontSize: 12)),
        onTap: explain,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            key: const ValueKey('trip-sharing-info'),
            tooltip: l10n.tripSharingInfoTooltip,
            icon: Icon(Icons.info_outline_rounded, color: context.textSecondary),
            onPressed: explain,
          ),
          Switch(
            key: const ValueKey('trip-sharing-switch'),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.brandBlue,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: GuidyUi.mist.withValues(alpha: 0.6),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            value: on,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              TripSharing.set(v);
            },
          ),
        ]),
      ),
    );
  }

  /// Whether the Home <-> Work lines are known yet; until then the switch
  /// says how to get them.
  bool _commuteHasLines = true;
  // False when the phone blocks Guidy's notifications (null: unknown).
  bool? _notificationsAllowed;

  Future<void> _checkNotificationsAllowed() async {
    final allowed = await CommuteNotifications.notificationsAllowed();
    if (mounted) setState(() => _notificationsAllowed = allowed);
  }

  /// Commute notifications: on by default, with a switch for each kind.
  Widget _commuteNotifications(BuildContext context, AppLocalizations l10n) {
    Widget toggle({
      Key? key,
      required IconData icon,
      required String title,
      String? subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
      bool indent = false,
      VoidCallback? onInfo,
    }) =>
        SwitchListTile(
          key: key,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.brandBlue,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: GuidyUi.mist.withValues(alpha: 0.6),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          contentPadding: EdgeInsetsDirectional.only(start: indent ? 56 : 16, end: 16),
          secondary: indent ? null : Icon(icon, color: context.textSecondary),
          title: onInfo == null
              ? _rowTitle(title)
              : Row(children: [
                  Flexible(child: _rowTitle(title)),
                  IconButton(
                    key: const ValueKey('commute-notifs-info'),
                    tooltip: l10n.commuteInfoTooltip,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.info_outline_rounded, size: 22, color: context.textSecondary),
                    onPressed: onInfo,
                  ),
                ]),
          subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
        );

    Future<void> save(CommuteSettings next, {bool askPermission = false}) async {
      await CommuteStore.saveSettings(next);
      if (askPermission) await CommuteNotifications.requestPermission();
      await CommuteNotifications.reschedule();
      await _checkNotificationsAllowed();
    }

    return ValueListenableBuilder<CommuteSettings>(
      valueListenable: CommuteStore.settings,
      builder: (context, s, _) => Column(children: [
        toggle(
          key: const ValueKey('commute-notifs'),
          icon: Icons.notifications_active_outlined,
          title: l10n.commuteNotifsLabel,
          subtitle: _commuteHasLines
              ? l10n.commuteNotifsSubtitle
              : '${l10n.commuteNotifsSubtitle}\n${l10n.commuteNotifsNeedHomeWork}',
          onInfo: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              key: const ValueKey('commute-notifs-info-dialog'),
              title: Text(l10n.commuteInfoTitle),
              content: SingleChildScrollView(child: Text(l10n.commuteInfoBody, style: const TextStyle(height: 1.4))),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.whatsNewOk))],
            ),
          ),
          value: s.enabled,
          onChanged: (v) => save(s.copyWith(enabled: v), askPermission: v),
        ),
        if (s.enabled && _notificationsAllowed == false)
          Padding(
            key: const ValueKey('commute-notifs-blocked'),
            padding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notifications_off_outlined, size: 18, color: Color(0xFFE5484D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.commuteNotifsBlocked,
                      style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
                ),
              ]),
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: Text(l10n.commuteNotifsOpenSettings),
              ),
            ]),
          ),
        if (s.enabled) ...[
          toggle(
            key: const ValueKey('commute-notifs-easier'),
            icon: Icons.schedule_rounded,
            title: l10n.commuteNotifsEasier,
            value: s.easier,
            indent: true,
            onChanged: (v) => save(s.copyWith(easier: v)),
          ),
          toggle(
            key: const ValueKey('commute-notifs-last'),
            icon: Icons.nightlight_round,
            title: l10n.commuteNotifsLastService,
            value: s.lastService,
            indent: true,
            onChanged: (v) => save(s.copyWith(lastService: v)),
          ),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String text, BuildContext context) {
    return GuidySectionLabel(text, padding: const EdgeInsetsDirectional.fromSTEB(28, 22, 20, 10));
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    // The background color lives on the inner Material, not this
    // Container's decoration -- ListTile paints its background/ink
    // splashes on the nearest Material ancestor, and an opaque
    // DecoratedBox between ListTile and that Material hides those
    // effects entirely (a well-known Flutter framework assertion).
    // The outer Container exists only for the margin and the design's
    // drop-shadow, which Material's own elevation doesn't replicate.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuidyUi.radius),
        boxShadow: GuidyUi.cardShadow(context),
      ),
      child: Material(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(GuidyUi.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  /// Row label in the design: upper-case, 13pt, in the row's colour.
  Widget _rowTitle(String text, {Color? color}) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: color ?? GuidyUi.heading(context), fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.isDark ? Colors.white10 : GuidyUi.mist.withValues(alpha: 0.35));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: simpleMode,
      builder: (context, simple, _) => _buildSettings(context, simple),
    );
  }

  /// Simple mode keeps what an everyday rider needs (dark mode, language,
  /// log out, account deletion, contact) and hides the rest: commute
  /// alerts, the tutorial and change password. The switch to leave simple mode
  /// is a big labelled button at the top.
  Widget _buildSettings(BuildContext context, bool simple) {
    final l10n = AppLocalizations.of(context);
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      body: ListView(
        controller: widget.scrollController,
        children: [
          GuidyHeader(
            title: l10n.settingsTitle,
            onBack: widget.onGoHome,
            showBack: widget.onGoHome != null,
            // Settings has its own language row below; no second switch.
            showLanguageToggle: false,
          ),
          if (simple)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.accessibility_new_rounded, size: 30, color: context.textPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.simpleSettingsOn,
                            key: const ValueKey('simple_settings_on'),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.simpleSettingsOnHint, style: TextStyle(fontSize: 18, color: context.textSecondary, height: 1.3)),
                  const SizedBox(height: 12),
                  SimpleButton(
                    key: const ValueKey('simple_turn_off'),
                    icon: Icons.toggle_off_rounded,
                    label: l10n.simpleTurnOff,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      simpleMode.set(false);
                    },
                  ),
                ],
              ),
            ),
          _sectionLabel(l10n.accountSectionLabel, context),
          _card(context, children: [
            ListTile(
              leading: Icon(Icons.person_rounded, color: AppColors.brandBlue, size: 26),
              title: _rowTitle(
                user == null || user.isAnonymous
                    ? l10n.guestLabel
                    : ((user.displayName != null && user.displayName!.trim().isNotEmpty)
                        ? user.displayName!.trim()
                        : (user.email ?? l10n.guestLabel)),
              ),
              subtitle: (user != null &&
                      !user.isAnonymous &&
                      user.displayName != null &&
                      user.displayName!.trim().isNotEmpty &&
                      user.email != null)
                  ? Text(
                      user.email!,
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    )
                  : null,
            ),
            // Email/password accounts only: Google and guest have no
            // password here to change.
            if (!simple && user != null && user.providerData.any((p) => p.providerId == 'password')) ...[
              _divider(context),
              ListTile(
                leading: Icon(Icons.password_rounded, color: context.textSecondary),
                title: _rowTitle(l10n.changePasswordButton),
                onTap: () async {
                  final changed = await showChangePasswordSheet(context);
                  if (changed == true && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.changePasswordSuccess)));
                  }
                },
              ),
            ],
            _divider(context),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: context.accentAmber),
              title: _rowTitle(l10n.logOut, color: context.accentAmber),
              onTap: () async {
                if (simple &&
                    !await SimpleUi.confirm(
                      context,
                      title: l10n.simpleLogOutTitle,
                      body: l10n.simpleLogOutBody,
                      yes: l10n.simpleLogOutYes,
                      no: l10n.simpleKeepGoing,
                    )) {
                  return;
                }
                await AccountService.clearUserDataOnSignOut();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            // Shown in simple mode too: Play wants deletion reachable in the
            // app, and it hid behind turning simple mode off (QA
            // 2026-10-22). It still asks before deleting anything.
            _divider(context),
            ListTile(
              // Red, not the amber of Log Out: this one can't be undone.
              // A guest is a real (anonymous) account holding their
              // legal-consent records, so the action stays, but "Delete
              // Account" reads oddly to someone who never made one.
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.errorRed),
              title: _rowTitle(isGuest ? l10n.deleteGuestDataButton : l10n.deleteAccountButton,
                  color: AppColors.errorRed),
              onTap: () => _confirmAndDeleteAccount(l10n, isGuest: isGuest),
            ),
          ]),

          _sectionLabel(l10n.preferencesSectionLabel, context),
          _card(context, children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeController,
              builder: (context, mode, _) {
                // Resolve "system" against the current platform brightness so
                // the switch shows the right state even before the user has
                // ever overridden it.
                final isDarkNow = mode == ThemeMode.dark ||
                    (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                return SwitchListTile(
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.brandBlue,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: GuidyUi.mist.withValues(alpha: 0.6),
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                  secondary: Icon(Icons.dark_mode_outlined, color: context.textSecondary),
                  title: _rowTitle(l10n.darkModeLabel),
                  subtitle: Text(l10n.darkModeSubtitle, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  value: isDarkNow,
                  onChanged: (val) {
                    themeController.setDarkMode(val);
                    AnalyticsService.logDarkModeToggled(val);
                  },
                );
              },
            ),
            _divider(context),
            if (!simple) ...[
            ValueListenableBuilder<bool>(
              valueListenable: simpleMode,
              builder: (context, on, _) => SwitchListTile(
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.brandBlue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: GuidyUi.mist.withValues(alpha: 0.6),
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                secondary: Icon(Icons.accessibility_new_rounded, color: context.textSecondary),
                title: _rowTitle(l10n.simpleModeLabel),
                subtitle: Text(l10n.simpleModeSubtitle, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                value: on,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  simpleMode.set(val);
                },
              ),
            ),
            _divider(context),
            _commuteNotifications(context, l10n),
            if (CommuteNotifications.testHook)
              ListTile(
                key: const ValueKey('debug-commute-test'),
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Debug: send a test commute alert in 1 min'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final at = await CommuteNotifications.debugScheduleTest();
                  messenger.showSnackBar(SnackBar(content: Text(at == null ? 'Not scheduled' : 'Scheduled for $at')));
                },
              ),
            _divider(context),
            _tripSharing(context, l10n),
            _divider(context),
            ],
            ListTile(
              leading: Icon(Icons.language, color: context.textSecondary),
              title: _rowTitle(l10n.languageSwitcherTitle),
              trailing: Text(
                localeController.isArabic ? l10n.languageArabic : l10n.languageEnglish,
                style: TextStyle(color: context.textSecondary),
              ),
              onTap: () => _showLanguagePicker(l10n),
            ),
            if (!simple) ...[
            _divider(context),
            ListTile(
              leading: Icon(Icons.tips_and_updates_outlined, color: context.textSecondary),
              title: _rowTitle(l10n.settingsReplayTutorial),
              subtitle: Text(
                l10n.settingsReplayTutorialSubtitle,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              onTap: TourService.replay,
            ),
            ],
          ]),

          _sectionLabel(l10n.supportSectionLabel, context),
          _card(context, children: [
            ListTile(
              leading: const Icon(Icons.mail_outline, color: AppColors.brandBlue),
              title: _rowTitle(l10n.contactUsLabel, color: AppColors.brandBlue),
              subtitle: Text(_contactEmail, style: TextStyle(color: context.textSecondary, fontSize: 12)),
              trailing: Icon(Icons.open_in_new, size: 18, color: context.textSecondary),
              onTap: () => _launchContactEmail(l10n),
            ),
            _divider(context),
            ListTile(
              leading: const Icon(Icons.star_outline_rounded, color: AppColors.brandBlue),
              title: _rowTitle(l10n.rateGuidyLabel, color: AppColors.brandBlue),
              onTap: () => ReviewService.openStoreListing(),
            ),
            _divider(context),
            const HideBannerTile(),
            // Only where Google's consent platform says the user must be able
            // to change their ad choices (EEA/UK). No l10n key, same reason
            // as the terms row below.
            ValueListenableBuilder<bool>(
              valueListenable: ConsentService.instance.privacyOptionsRequired,
              builder: (context, required, _) {
                if (!required) return const SizedBox.shrink();
                final ar = Localizations.localeOf(context).languageCode == 'ar';
                return Column(children: [
                  ListTile(
                    leading: const Icon(Icons.ads_click, color: AppColors.brandBlue),
                    title: _rowTitle(ar ? 'خيارات خصوصية الإعلانات' : 'Ad privacy settings', color: AppColors.brandBlue),
                    onTap: () => ConsentService.instance.showPrivacyOptions(),
                  ),
                  _divider(context),
                ]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.brandBlue),
              title: _rowTitle(l10n.privacyPolicyLabel, color: AppColors.brandBlue),
              trailing: Icon(Icons.open_in_new, size: 18, color: context.textSecondary),
              // guidyapp.com (Firebase Hosting), generated from the markdown
              // sources by website/legal/build_legal.py. The .web.app address serves the
              // same pages.
              //
              // Follows the app's language rather than the phone's: someone
              // reading Guidy in Arabic should not be handed an English
              // legal document, and Localizations.localeOf reflects the
              // in-app language picker, not the system locale.
              onTap: () => launchUrl(
                Uri.parse(Localizations.localeOf(context).languageCode == 'ar'
                    ? 'https://guidyapp.com/privacy-ar'
                    : 'https://guidyapp.com/privacy'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            _divider(context),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.brandBlue),
              // No l10n key for this one -- flutter gen-l10n isn't runnable
              // from this environment, and hand-editing the generated
              // app_localizations*.dart files has bitten this repo before
              // (see website/legal/build_legal.py). Same locale-conditional
              // pattern used all over the rest of the app (e.g.
              // LinesScreen._currentLangCode) instead of a generated getter.
              title: _rowTitle(
                Localizations.localeOf(context).languageCode == 'ar' ? 'الشروط والأحكام' : 'Terms and Conditions',
                color: AppColors.brandBlue,
              ),
              trailing: Icon(Icons.open_in_new, size: 18, color: context.textSecondary),
              onTap: () => launchUrl(
                Uri.parse(Localizations.localeOf(context).languageCode == 'ar'
                    ? 'https://guidyapp.com/terms-ar'
                    : 'https://guidyapp.com/terms'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            _divider(context),
            ListTile(
              key: const ValueKey('patch-notes-row'),
              leading: Icon(Icons.history_rounded, color: context.textSecondary),
              title: _rowTitle(l10n.patchNotesTitle),
              subtitle: Text(l10n.patchNotesSubtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              trailing: Icon(Icons.chevron_right_rounded, color: context.textSecondary),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatchNotesScreen())),
            ),
          ]),

          const SizedBox(height: 32),
          Center(
            child: Image.asset(
              context.isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
              height: 40,
              semanticLabel: 'Guidy Logo',
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(_version, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
