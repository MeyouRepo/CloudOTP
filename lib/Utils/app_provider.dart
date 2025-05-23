/*
 * Copyright (c) 2024 Robert-Stackflow.
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.
 * If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:animated_custom_dropdown/models/dropdown_mixin.dart';
import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:cloudotp/Models/auto_backup_log.dart';
import 'package:cloudotp/Screens/Setting/setting_general_screen.dart';
import 'package:cloudotp/Screens/main_screen.dart';
import 'package:cloudotp/Utils/Tuple/tuple.dart';
import 'package:flutter/material.dart';
import 'package:queue/queue.dart';

import '../Screens/home_screen.dart';
import '../generated/l10n.dart';
import 'hive_util.dart';

GlobalKey<GeneralSettingScreenState> generalSettingScreenKey =
    GlobalKey<GeneralSettingScreenState>();

GeneralSettingScreenState? get generalSettingScreenState =>
    generalSettingScreenKey.currentState;

GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

HomeScreenState? get homeScreenState => homeScreenKey.currentState;

MainScreenState? get mainScreenState => mainScreenKey.currentState;

// GlobalKey<KeyboardHandlerState> keyboardHandlerKey =
//     GlobalKey<KeyboardHandlerState>();
//
// KeyboardHandlerState? get keyboardHandlerState =>
//     keyboardHandlerKey.currentState;

Queue autoBackupQueue = Queue();

AppProvider appProvider = AppProvider();

bool haveMigratedToSupportDirectory = false;

enum AutoLockTime {
  immediately,
  after30Seconds,
  after1Minute,
  after3Minutes,
  after5Minutes,
  after10Minutes;

  int get seconds {
    switch (this) {
      case AutoLockTime.immediately:
        return 0;
      case AutoLockTime.after30Seconds:
        return 30;
      case AutoLockTime.after1Minute:
        return 60;
      case AutoLockTime.after3Minutes:
        return 60 * 3;
      case AutoLockTime.after5Minutes:
        return 60 * 5;
      case AutoLockTime.after10Minutes:
        return 60 * 10;
    }
  }

  String get label {
    switch (this) {
      case AutoLockTime.immediately:
        return S.current.immediatelyLock;
      case AutoLockTime.after30Seconds:
        return S.current.after30SecondsLock;
      case AutoLockTime.after1Minute:
        return S.current.after1MinuteLock;
      case AutoLockTime.after3Minutes:
        return S.current.after3MinutesLock;
      case AutoLockTime.after5Minutes:
        return S.current.after5MinutesLock;
      case AutoLockTime.after10Minutes:
        return S.current.after10MinutesLock;
    }
  }
}

class AutoLockOption implements DropdownMixin {
  final String label;
  final AutoLockTime autoLockTime;

  const AutoLockOption(this.label, this.autoLockTime);

  static List<AutoLockOption> getOptions() {
    return [
      AutoLockOption(S.current.immediatelyLock, AutoLockTime.immediately),
      AutoLockOption(S.current.after30SecondsLock, AutoLockTime.after30Seconds),
      AutoLockOption(S.current.after1MinuteLock, AutoLockTime.after1Minute),
      AutoLockOption(S.current.after3MinutesLock, AutoLockTime.after3Minutes),
      AutoLockOption(S.current.after5MinutesLock, AutoLockTime.after5Minutes),
      AutoLockOption(S.current.after10MinutesLock, AutoLockTime.after10Minutes),
    ];
  }

  static AutoLockOption? fromAutoLockTime(AutoLockTime autoLockTime) {
    return getOptions().firstWhere(
      (option) => option.autoLockTime == autoLockTime,
      orElse: () => getOptions().first,
    );
  }

  @override
  String get display => label;

  @override
  String get selection => display;

  @override
  bool operator ==(Object other) {
    return other is AutoLockOption && autoLockTime == other.autoLockTime;
  }

  @override
  int get hashCode => autoLockTime.hashCode;
}

class AppProvider with ChangeNotifier {
  String currentDatabasePassword = "";

  String latestVersion = "";

  bool preventLock = false;

  bool shownShortcutHelp = false;

  final List<AutoBackupLog> _autoBackupLogs = [];

  List<AutoBackupLog> get autoBackupLogs => _autoBackupLogs;

  pushAutoBackupLog(AutoBackupLog value) {
    _autoBackupLogs.insert(0, value);
    notifyListeners();
  }

  clearAutoBackupLogs() {
    _autoBackupLogs.removeWhere((element) => element.lastStatus.isCompleted);
    notifyListeners();
  }

  LoadingStatus _autoBackupStatus = LoadingStatus.none;

  LoadingStatus get autoBackupLoadingStatus => _autoBackupStatus;

  set autoBackupLoadingStatus(LoadingStatus value) {
    _autoBackupStatus = value;
    notifyListeners();
  }

  bool _showCloudEntry = false;

  bool get canShowCloudBackupButton => _showCloudEntry;

  set canShowCloudBackupButton(bool value) {
    _showCloudEntry = value;
    notifyListeners();
  }

  bool _autoHideCode = ChewieHiveUtil.getBool(CloudOTPHiveUtil.autoHideCodeKey);

  bool get autoHideCode => _autoHideCode;

  set autoHideCode(bool value) {
    _autoHideCode = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.autoHideCodeKey, value);
    notifyListeners();
  }

  bool _autoDisplayNextCode =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.autoDisplayNextCodeKey);

  bool get autoDisplayNextCode => _autoDisplayNextCode;

  set autoDisplayNextCode(bool value) {
    _autoDisplayNextCode = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.autoDisplayNextCodeKey, value);
    notifyListeners();
  }

  bool _hideProgressBar =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.hideProgressBarKey);

  bool get hideProgressBar => _hideProgressBar;

  set hideProgressBar(bool value) {
    _hideProgressBar = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.hideProgressBarKey, value);
    notifyListeners();
  }

  bool _showEye = ChewieHiveUtil.getBool(CloudOTPHiveUtil.showEyeKey);

  bool get showEye => _showEye;

  set showEye(bool value) {
    _showEye = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.showEyeKey, value);
    notifyListeners();
  }

  bool _enableLandscapeInTablet =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.enableLandscapeInTabletKey);

  bool get enableLandscapeInTablet => _enableLandscapeInTablet;

  set enableLandscapeInTablet(bool value) {
    _enableLandscapeInTablet = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.enableLandscapeInTabletKey, value)
        .then((value) {
      ResponsiveUtil.restartApp(chewieProvider.rootContext);
    });
    notifyListeners();
  }

  bool _canPopByProvider = false;

  bool get canPopByProvider => _canPopByProvider;

  set canPopByProvider(bool value) {
    _canPopByProvider = value;
    notifyListeners();
  }

  bool _showCloudBackupButton = ChewieHiveUtil.getBool(
      CloudOTPHiveUtil.showCloudBackupButtonKey,
      defaultValue: ResponsiveUtil.isLandscape(false));

  bool get showCloudBackupButton => _showCloudBackupButton;

  set showCloudBackupButton(bool value) {
    _showCloudBackupButton = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.showCloudBackupButtonKey, value);
    notifyListeners();
  }

  bool _showLayoutButton =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.showLayoutButtonKey);

  bool get showLayoutButton => _showLayoutButton;

  set showLayoutButton(bool value) {
    _showLayoutButton = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.showLayoutButtonKey, value);
    notifyListeners();
  }

  bool _showSortButton =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.showSortButtonKey);

  bool get showSortButton => _showSortButton;

  set showSortButton(bool value) {
    _showSortButton = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.showSortButtonKey, value);
    notifyListeners();
  }

  bool _showBackupLogButton = ChewieHiveUtil.getBool(
      CloudOTPHiveUtil.showBackupLogButtonKey,
      defaultValue: ResponsiveUtil.isLandscape(false));

  bool get showBackupLogButton => _showBackupLogButton;

  set showBackupLogButton(bool value) {
    _showBackupLogButton = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.showBackupLogButtonKey, value);
    notifyListeners();
  }

  bool _dragToReorder = ChewieHiveUtil.getBool(
      CloudOTPHiveUtil.dragToReorderKey,
      defaultValue: !ResponsiveUtil.isMobile());

  bool get dragToReorder => _dragToReorder;

  set dragToReorder(bool value) {
    _dragToReorder = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.dragToReorderKey, value);
    notifyListeners();
  }

  bool _enableFrostedGlassEffect = ChewieHiveUtil.getBool(
      CloudOTPHiveUtil.enableFrostedGlassEffectKey,
      defaultValue: false);

  bool get enableFrostedGlassEffect => _enableFrostedGlassEffect;

  set enableFrostedGlassEffect(bool value) {
    _enableFrostedGlassEffect = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.enableFrostedGlassEffectKey, value);
    notifyListeners();
  }

  bool _hideAppbarWhenScrolling =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.hideAppbarWhenScrollingKey);

  bool get hideAppbarWhenScrolling => _hideAppbarWhenScrolling;

  set hideAppbarWhenScrolling(bool value) {
    _hideAppbarWhenScrolling = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.hideAppbarWhenScrollingKey, value);
    notifyListeners();
  }

  bool _hideBottombarWhenScrolling =
      ChewieHiveUtil.getBool(CloudOTPHiveUtil.hideBottombarWhenScrollingKey);

  bool get hideBottombarWhenScrolling => _hideBottombarWhenScrolling;

  set hideBottombarWhenScrolling(bool value) {
    _hideBottombarWhenScrolling = value;
    ChewieHiveUtil.put(CloudOTPHiveUtil.hideBottombarWhenScrollingKey, value);
    notifyListeners();
  }

  // Map<Type, Action<Intent>> _dynamicShortcuts =
  //     KeyboardHandlerState.mainScreenShortcuts;

  // Map<Type, Action<Intent>> get dynamicShortcuts => _dynamicShortcuts;
  //
  // set dynamicShortcuts(Map<Type, Action<Intent>> value) {
  //   _dynamicShortcuts = value;
  //   notifyListeners();
  // }

  AutoLockTime _autoLockTime = CloudOTPHiveUtil.getAutoLockTime();

  AutoLockTime get autoLockTime => _autoLockTime;

  set autoLockTime(AutoLockTime value) {
    if (value != _autoLockTime) {
      _autoLockTime = value;
      notifyListeners();
      CloudOTPHiveUtil.setAutoLockTime(value);
    }
  }
}
