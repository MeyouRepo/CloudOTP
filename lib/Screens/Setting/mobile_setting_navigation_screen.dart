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

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:cloudotp/Screens/Setting/setting_appearance_screen.dart';
import 'package:cloudotp/Screens/Setting/setting_backup_screen.dart';
import 'package:cloudotp/Screens/Setting/setting_general_screen.dart';
import 'package:cloudotp/Screens/Setting/setting_operation_screen.dart';
import 'package:cloudotp/Screens/Setting/setting_safe_screen.dart';
import 'package:flutter/material.dart';

import '../../Utils/app_provider.dart';
import '../../generated/l10n.dart';

class MobileSettingNavigationScreen extends StatefulWidget {
  const MobileSettingNavigationScreen({super.key});

  static const String routeName = "/setting/navigation";

  @override
  State<MobileSettingNavigationScreen> createState() =>
      _MobileSettingNavigationScreenState();
}

class _MobileSettingNavigationScreenState extends State<MobileSettingNavigationScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Scaffold(
        appBar: ResponsiveAppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: S.current.setting,
          actions: const [
            BlankIconButton(),
            SizedBox(width: 5),
          ],
        ),
        body: EasyRefresh(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              EntryItem(
                title: S.current.generalSetting,
                leading: Icons.now_widgets_outlined,
                showLeading: true,
                onTap: () {
                  RouteUtil.pushCupertinoRoute(
                    context,
                    GeneralSettingScreen(key: generalSettingScreenKey),
                  );
                },
              ),
              const SizedBox(height: 10),
              EntryItem(
                title: S.current.appearanceSetting,
                leading: Icons.color_lens_outlined,
                showLeading: true,
                onTap: () {
                  RouteUtil.pushCupertinoRoute(
                      context, const AppearanceSettingScreen());
                },
              ),
              const SizedBox(height: 10),
              EntryItem(
                title: S.current.operationSetting,
                leading: Icons.handyman_outlined,
                showLeading: true,
                onTap: () {
                  RouteUtil.pushCupertinoRoute(
                      context, const OperationSettingScreen());
                },
              ),
              const SizedBox(height: 10),
              EntryItem(
                title: S.current.backupSetting,
                leading: Icons.backup_outlined,
                showLeading: true,
                onTap: () {
                  RouteUtil.pushCupertinoRoute(
                      context, const BackupSettingScreen());
                },
              ),
              const SizedBox(height: 10),
              EntryItem(
                title: S.current.safeSetting,
                leading: Icons.privacy_tip_outlined,
                showLeading: true,
                onTap: () {
                  RouteUtil.pushCupertinoRoute(
                      context, const SafeSettingScreen());
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
