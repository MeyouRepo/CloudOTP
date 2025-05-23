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

import 'dart:typed_data';

import 'package:cloudotp/Models/cloud_service_config.dart';
import 'package:cloudotp/TokenUtils/Cloud/cloud_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud/googledrive_response.dart';

import '../../Database/cloud_service_config_dao.dart';
import '../../TokenUtils/Cloud/googledrive_cloud_service.dart';
import '../../TokenUtils/export_token_util.dart';
import '../../TokenUtils/import_token_util.dart';
import 'package:awesome_chewie/awesome_chewie.dart';
import '../../Widgets/BottomSheet/Backups/googledrive_backups_bottom_sheet.dart';
import '../../generated/l10n.dart';

class GoogleDriveServiceScreen extends StatefulWidget {
  const GoogleDriveServiceScreen({
    super.key,
  });

  static const String routeName = "/service/googledrive";

  @override
  State<GoogleDriveServiceScreen> createState() =>
      _GoogleDriveServiceScreenState();
}

class _GoogleDriveServiceScreenState extends State<GoogleDriveServiceScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  CloudServiceConfig? _googledriveCloudServiceConfig;
  GoogleDriveCloudService? _googledriveCloudService;
  bool inited = false;

  CloudServiceConfig get currentConfig => _googledriveCloudServiceConfig!;

  CloudService get currentService => _googledriveCloudService!;

  bool get _configInitialized {
    return _googledriveCloudServiceConfig != null;
  }

  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  loadConfig() async {
    _googledriveCloudServiceConfig =
        await CloudServiceConfigDao.getGoogleDriveConfig();
    if (_googledriveCloudServiceConfig != null) {
      _sizeController.text = _googledriveCloudServiceConfig!.size;
      _accountController.text = _googledriveCloudServiceConfig!.account ?? "";
      _emailController.text = _googledriveCloudServiceConfig!.email ?? "";
      _googledriveCloudService = GoogleDriveCloudService(
        _googledriveCloudServiceConfig!,
        onConfigChanged: updateConfig,
      );
    } else {
      _googledriveCloudServiceConfig =
          CloudServiceConfig.init(type: CloudServiceType.GoogleDrive);
      await CloudServiceConfigDao.insertConfig(_googledriveCloudServiceConfig!);
      _googledriveCloudService = GoogleDriveCloudService(
        _googledriveCloudServiceConfig!,
        onConfigChanged: updateConfig,
      );
    }
    if (_googledriveCloudService != null) {
      _googledriveCloudServiceConfig!.configured =
          await _googledriveCloudService!.hasConfigured();
      _googledriveCloudServiceConfig!.connected =
          await _googledriveCloudService!.isConnected();
      if (_googledriveCloudServiceConfig!.configured &&
          !_googledriveCloudServiceConfig!.connected) {
        IToast.showTop(S.current.cloudConnectionError);
      }
      updateConfig(_googledriveCloudServiceConfig!);
    }
    inited = true;
    setState(() {});
  }

  updateConfig(CloudServiceConfig config) {
    setState(() {
      _googledriveCloudServiceConfig = config;
    });
    _sizeController.text = _googledriveCloudServiceConfig!.size;
    _accountController.text = _googledriveCloudServiceConfig!.account ?? "";
    _emailController.text = _googledriveCloudServiceConfig!.email ?? "";
    CloudServiceConfigDao.updateConfig(_googledriveCloudServiceConfig!);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return inited
        ? _buildBody()
        : ItemBuilder.buildLoadingDialog(
            context: context,
            background: Colors.transparent,
            text: S.current.cloudConnecting,
            mainAxisAlignment: MainAxisAlignment.start,
            topPadding: 100,
          );
  }

  ping({
    bool showLoading = true,
    bool showSuccessToast = true,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.cloudConnecting);
    }
    await currentService.authenticate().then((value) async {
      setState(() {
        currentConfig.connected = value == CloudServiceStatus.success;
      });
      if (!currentConfig.connected) {
        switch (value) {
          case CloudServiceStatus.connectionError:
            IToast.show(S.current.cloudConnectionError);
            break;
          case CloudServiceStatus.unauthorized:
            IToast.show(S.current.cloudOauthFailed);
            break;
          default:
            IToast.show(S.current.cloudUnknownError);
            break;
        }
      } else {
        _googledriveCloudServiceConfig!.configured = true;
        updateConfig(_googledriveCloudServiceConfig!);
        if (showSuccessToast) IToast.show(S.current.cloudAuthSuccess);
      }
    });
    if (showLoading) CustomLoadingDialog.dismissLoading();
  }

  _buildBody() {
    return ListView(
      children: [
        if (_configInitialized) _enableInfo(),
        if (_configInitialized && currentConfig.connected) _accountInfo(),
        const SizedBox(height: 30),
        if (_configInitialized && !currentConfig.connected) _loginButton(),
        if (_configInitialized && currentConfig.connected) _operationButtons(),
        const SizedBox(height: 30),
      ],
    );
  }

  _enableInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: CheckboxItem(
        title: S.current.enable + S.current.cloudTypeGoogleDrive,
        value: _googledriveCloudServiceConfig?.enabled ?? false,
        onTap: () {
          setState(() {
            _googledriveCloudServiceConfig!.enabled =
                !_googledriveCloudServiceConfig!.enabled;
            CloudServiceConfigDao.updateConfigEnabled(
                _googledriveCloudServiceConfig!,
                _googledriveCloudServiceConfig!.enabled);
          });
        },
      ),
    );
  }

  _accountInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          InputItem(
            controller: _accountController,
            textInputAction: TextInputAction.next,
            disabled: true,
            title: S.current.cloudDisplayName,
          ),
          InputItem(
            controller: _emailController,
            textInputAction: TextInputAction.next,
            disabled: true,
            title: S.current.cloudEmail,
          ),
          InputItem(
            controller: _sizeController,
            textInputAction: TextInputAction.next,
            disabled: true,
            title: S.current.cloudSize,
          ),
        ],
      ),
    );
  }

  _loginButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RoundIconTextButton(
        text: S.current.cloudSignin,
        background: Theme.of(context).primaryColor,
        fontSizeDelta: 2,
        onPressed: () async {
          try {
            ping();
          } catch (e, t) {
            ILogger.error("Failed to connect to google drive", e, t);
            IToast.show(S.current.cloudConnectionError);
          }
        },
      ),
    );
  }

  _operationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: CustomOutlinedButton(
              text: S.current.cloudPullBackup,
              padding: const EdgeInsets.symmetric(vertical: 12),
              outline: Theme.of(context).primaryColor,
              color: Theme.of(context).primaryColor,
              fontSizeDelta: 2,
              onPressed: () async {
                CustomLoadingDialog.showLoading(title: S.current.cloudPulling);
                try {
                  List<GoogleDriveFileInfo>? files =
                      await _googledriveCloudService!.listBackups();
                  if (files == null) {
                    CustomLoadingDialog.dismissLoading();
                    IToast.show(S.current.cloudPullFailed);
                    return;
                  }
                  CloudServiceConfigDao.updateLastPullTime(
                      _googledriveCloudServiceConfig!);
                  CustomLoadingDialog.dismissLoading();
                  files.sort((a, b) =>
                      b.lastModifiedDateTime.compareTo(a.lastModifiedDateTime));
                  if (files.isNotEmpty) {
                    BottomSheetBuilder.showBottomSheet(
                      context,
                      responsive: true,
                      (dialogContext) => GoogleDriveBackupsBottomSheet(
                        files: files,
                        cloudService: _googledriveCloudService!,
                        onSelected: (selectedFile) async {
                          var dialog = showProgressDialog(
                            S.current.cloudPulling,
                            showProgress: true,
                          );
                          Uint8List? res =
                              await _googledriveCloudService!.downloadFile(
                            selectedFile.id,
                            onProgress: (c, t) {
                              dialog.updateProgress(progress: c / t);
                            },
                          );
                          ImportTokenUtil.importFromCloud(context, res, dialog);
                        },
                      ),
                    );
                  } else {
                    IToast.show(S.current.cloudNoBackupFile);
                  }
                } catch (e, t) {
                  ILogger.error("Failed to pull from google drive", e, t);
                  CustomLoadingDialog.dismissLoading();
                  IToast.show(S.current.cloudPullFailed);
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RoundIconTextButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              background: Theme.of(context).primaryColor,
              text: S.current.cloudPushBackup,
              fontSizeDelta: 2,
              onPressed: () async {
                ExportTokenUtil.backupEncryptToCloud(
                  config: _googledriveCloudServiceConfig!,
                  cloudService: _googledriveCloudService!,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RoundIconTextButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              background: Colors.red,
              text: S.current.cloudLogout,
              fontSizeDelta: 2,
              onPressed: () async {
                DialogBuilder.showConfirmDialog(context,
                    title: S.current.cloudLogout,
                    message: S.current.cloudLogoutMessage,
                    onTapConfirm: () async {
                  await _googledriveCloudService!.signOut();
                  setState(() {
                    _googledriveCloudServiceConfig!.connected = false;
                    _googledriveCloudServiceConfig!.account = "";
                    _googledriveCloudServiceConfig!.email = "";
                    _googledriveCloudServiceConfig!.totalSize =
                        _googledriveCloudServiceConfig!.remainingSize =
                            _googledriveCloudServiceConfig!.usedSize = -1;
                    updateConfig(_googledriveCloudServiceConfig!);
                  });
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
