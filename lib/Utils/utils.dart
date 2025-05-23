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

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:cloudotp/Database/category_dao.dart';
import 'package:cloudotp/Database/database_manager.dart';
import 'package:cloudotp/Database/token_category_binding_dao.dart';
import 'package:cloudotp/Database/token_dao.dart';
import 'package:cloudotp/Models/opt_token.dart';
import 'package:cloudotp/Models/token_category.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../Screens/Setting/about_setting_screen.dart';
import '../Screens/Setting/mobile_setting_navigation_screen.dart';
import '../Screens/Setting/setting_safe_screen.dart';
import '../TokenUtils/code_generator.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../generated/l10n.dart';
import 'app_provider.dart';
import 'constant.dart';
import 'hive_util.dart';

class Utils {
  static Future<Rect> getWindowRect(BuildContext context) async {
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    return Rect.fromLTWH(
        0, 0, primaryDisplay.size.width, primaryDisplay.size.height);
  }

  static Map<String, dynamic> parseEndpoint(String endpoint) {
    final parts = endpoint.split(':');
    if (parts.length == 2) {
      return {
        'host': parts[0],
        'port': int.tryParse(parts[1]),
      };
    } else {
      return {
        'host': endpoint,
        'port': null,
      };
    }
  }

  static Future<List<MenuItem>> getTrayTokenMenuItems() async {
    List<TokenCategory> categories =
        DatabaseManager.initialized ? await CategoryDao.listCategories() : [];
    List<OtpToken> tokens =
        DatabaseManager.initialized ? await TokenDao.listTokens() : [];
    tokens.sort((a, b) => a.issuer.compareTo(b.issuer));
    for (TokenCategory category in categories) {
      category.tokens = await BindingDao.getTokens(category.uid);
      category.tokens.sort((a, b) => a.issuer.compareTo(b.issuer));
    }
    List<TokenCategory> haveTokenCategories =
        categories.where((e) => e.tokens.isNotEmpty).toList();
    if (DatabaseManager.initialized && tokens.isNotEmpty) {
      return [
        MenuItem.separator(),
        MenuItem.submenu(
          key: TrayKey.copyTokenCode.key,
          label: S.current.allTokens,
          submenu: Menu(
            items: tokens
                .map(
                  (e) => MenuItem(
                    key: "${TrayKey.copyTokenCode.key}_${e.uid}",
                    label: e.issuer,
                  ),
                )
                .toList(),
          ),
        ),
        ...haveTokenCategories.map(
          (category) => MenuItem.submenu(
            key: "${TrayKey.copyTokenCode.key}_category_${category.uid}",
            label: category.title,
            submenu: Menu(
              items: category.tokens
                  .map(
                    (e) => MenuItem(
                      key: "${TrayKey.copyTokenCode.key}_${e.uid}",
                      label: e.issuer,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ];
    } else {
      return [];
    }
  }

  static Future<void> removeTray() async {
    await trayManager.destroy();
  }

  static Future<void> initTray() async {
    if (!ResponsiveUtil.isDesktop()) return;
    await trayManager.destroy();
    if (!ChewieHiveUtil.getBool(ChewieHiveUtil.showTrayKey)) {
      await trayManager.destroy();
      return;
    }

    // Ensure tray icon display in linux sandboxed environments
    if (Platform.environment.containsKey('FLATPAK_ID') ||
        Platform.environment.containsKey('SNAP')) {
      await trayManager.setIcon('com.cloudchewie.cloudotp');
    } else if (ResponsiveUtil.isWindows()) {
      await trayManager.setIcon('assets/logo-transparent.ico');
    } else {
      await trayManager.setIcon('assets/logo-transparent.png');
    }

    bool lauchAtStartup = await LaunchAtStartup.instance.isEnabled();
    if (!ResponsiveUtil.isLinux()) {
      await trayManager.setToolTip(ResponsiveUtil.appName);
    }
    Menu menu = Menu(
      items: [
        MenuItem(
          key: TrayKey.checkUpdates.key,
          label: appProvider.latestVersion.isNotEmpty
              ? S.current.getNewVersion(appProvider.latestVersion)
              : S.current.checkUpdates,
        ),
        MenuItem(
          key: TrayKey.shortcutHelp.key,
          label: S.current.shortcutHelp,
        ),
        MenuItem.separator(),
        MenuItem(
          key: TrayKey.displayApp.key,
          label: S.current.displayAppTray,
        ),
        MenuItem(
          key: TrayKey.lockApp.key,
          label: S.current.lockAppTray,
        ),
        ...await getTrayTokenMenuItems(),
        MenuItem.separator(),
        MenuItem(
          key: TrayKey.setting.key,
          label: S.current.setting,
        ),
        MenuItem(
          key: TrayKey.officialWebsite.key,
          label: S.current.officialWebsiteTray,
        ),
        MenuItem(
          key: TrayKey.about.key,
          label: S.current.about,
        ),
        MenuItem(
          key: TrayKey.githubRepository.key,
          label: S.current.repoTray,
        ),
        MenuItem.separator(),
        MenuItem.checkbox(
          checked: lauchAtStartup,
          key: TrayKey.launchAtStartup.key,
          label: S.current.launchAtStartup,
        ),
        MenuItem.separator(),
        MenuItem(
          key: TrayKey.exitApp.key,
          label: S.current.exitAppTray,
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  static Future<void> initSimpleTray() async {
    if (!ResponsiveUtil.isDesktop()) return;
    await trayManager.destroy();
    if (!ChewieHiveUtil.getBool(ChewieHiveUtil.showTrayKey)) {
      await trayManager.destroy();
      return;
    }

    // Ensure tray icon display in linux sandboxed environments
    if (Platform.environment.containsKey('FLATPAK_ID') ||
        Platform.environment.containsKey('SNAP')) {
      await trayManager.setIcon('com.cloudchewie.cloudotp');
    } else if (ResponsiveUtil.isWindows()) {
      await trayManager.setIcon('assets/logo-transparent.ico');
    } else {
      await trayManager.setIcon('assets/logo-transparent.png');
    }

    bool lauchAtStartup = await LaunchAtStartup.instance.isEnabled();
    if (!ResponsiveUtil.isLinux()) {
      await trayManager.setToolTip(ResponsiveUtil.appName);
    }
    Menu menu = Menu(
      items: [
        MenuItem(
          key: TrayKey.displayApp.key,
          label: S.current.displayAppTray,
        ),
        MenuItem.separator(),
        MenuItem(
          key: TrayKey.officialWebsite.key,
          label: S.current.officialWebsiteTray,
        ),
        MenuItem(
          key: TrayKey.githubRepository.key,
          label: S.current.repoTray,
        ),
        MenuItem.separator(),
        MenuItem.checkbox(
          checked: lauchAtStartup,
          key: TrayKey.launchAtStartup.key,
          label: S.current.launchAtStartup,
        ),
        MenuItem.separator(),
        MenuItem(
          key: TrayKey.exitApp.key,
          label: S.current.exitAppTray,
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  static showHelp(BuildContext context) {
    if (appProvider.shownShortcutHelp) return;
    appProvider.shownShortcutHelp = true;
    // late OverlayEntry entry;
    // entry = OverlayEntry(
    //   builder: (context) {
    //     return KeyboardWidget(
    //       bindings: defaultCloudOTPShortcuts,
    //       callbackOnHide: () {
    //         appProvider.shownShortcutHelp = false;
    //         entry.remove();
    //       },
    //       title: Text(
    //         S.current.shortcut,
    //         style: ChewieTheme.textTheme.titleLarge,
    //       ),
    //     );
    //   },
    // );
    // Overlay.of(context).insert(entry);
    // return null;
  }

  static processTrayMenuItemClick(
    BuildContext context,
    MenuItem menuItem, [
    bool isSimple = false,
  ]) async {
    if (menuItem.key == TrayKey.displayApp.key) {
      ChewieUtils.displayApp();
    } else if (menuItem.key == TrayKey.shortcutHelp.key) {
      ChewieUtils.displayApp();
      Utils.showHelp(context);
    } else if (menuItem.key == TrayKey.lockApp.key) {
      if (CloudOTPHiveUtil.canLock()) {
        mainScreenState?.jumpToLock();
      } else {
        IToast.showDesktopNotification(
          S.current.noGestureLock,
          body: S.current.noGestureLockTip,
          actions: [S.current.cancel, S.current.goToSetGestureLock],
          onClick: () {
            ChewieUtils.displayApp();
            RouteUtil.pushDialogRoute(context, const SafeSettingScreen());
          },
          onClickAction: (index) {
            if (index == 1) {
              ChewieUtils.displayApp();
              RouteUtil.pushDialogRoute(context, const SafeSettingScreen());
            }
          },
        );
      }
    } else if (menuItem.key == TrayKey.setting.key) {
      ChewieUtils.displayApp();
      RouteUtil.pushDialogRoute(context, const MobileSettingNavigationScreen());
    } else if (menuItem.key == TrayKey.about.key) {
      ChewieUtils.displayApp();
      RouteUtil.pushDialogRoute(context, const AboutSettingScreen());
    } else if (menuItem.key == TrayKey.officialWebsite.key) {
      UriUtil.launchUrlUri(context, officialWebsite);
    } else if (menuItem.key.notNullOrEmpty &&
        menuItem.key!.startsWith(TrayKey.copyTokenCode.key)) {
      String uid = menuItem.key!.split('_').last;
      OtpToken? token = await TokenDao.getTokenByUid(uid);
      if (token != null) {
        double currentProgress = token.period == 0
            ? 0
            : (token.period * 1000 -
                    (DateTime.now().millisecondsSinceEpoch %
                        (token.period * 1000))) /
                (token.period * 1000);
        if (ChewieHiveUtil.getBool(CloudOTPHiveUtil.autoCopyNextCodeKey) &&
            currentProgress < autoCopyNextCodeProgressThrehold) {
          ChewieUtils.copy(context, CodeGenerator.getNextCode(token),
              toastText: S.current.alreadyCopiedNextCode);
          TokenDao.incTokenCopyTimes(token);
          IToast.showDesktopNotification(
            S.current.alreadyCopiedNextCode,
            body: CodeGenerator.getNextCode(token),
          );
        } else {
          ChewieUtils.copy(context, CodeGenerator.getCurrentCode(token));
          TokenDao.incTokenCopyTimes(token);
          IToast.showDesktopNotification(
            S.current.copySuccess,
            body: CodeGenerator.getCurrentCode(token),
          );
        }
      }
    } else if (menuItem.key == TrayKey.githubRepository.key) {
      UriUtil.launchUrlUri(context, repoUrl);
    } else if (menuItem.key == TrayKey.checkUpdates.key) {
      ChewieUtils.getReleases(
        context: context,
        showLoading: false,
        showUpdateDialog: true,
        showFailedToast: false,
        showLatestToast: false,
        showDesktopNotification: true,
      );
    } else if (menuItem.key == TrayKey.launchAtStartup.key) {
      menuItem.checked = !(menuItem.checked == true);
      ChewieHiveUtil.put(ChewieHiveUtil.launchAtStartupKey, menuItem.checked);
      generalSettingScreenState?.refreshLauchAtStartup();
      if (menuItem.checked == true) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
      if (isSimple) {
        Utils.initSimpleTray();
      } else {
        Utils.initTray();
      }
    } else if (menuItem.key == TrayKey.exitApp.key) {
      windowManager.close();
    }
  }
}
