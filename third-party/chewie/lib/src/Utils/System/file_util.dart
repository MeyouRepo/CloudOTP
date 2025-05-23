import 'dart:ffi';
import 'dart:io';

import 'package:awesome_chewie/src/Utils/General/responsive_util.dart';
import 'package:awesome_chewie/src/Utils/General/string_util.dart';
import 'package:awesome_chewie/src/Utils/General/time_util.dart';
import 'package:awesome_chewie/src/Utils/System/uri_util.dart';
import 'package:awesome_chewie/src/Utils/utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:win32/win32.dart';

import 'package:awesome_chewie/src/Models/github_response.dart';
import 'package:awesome_chewie/src/Widgets/Dialog/custom_dialog.dart';
import 'package:awesome_chewie/src/generated/l10n.dart';
import 'package:awesome_chewie/src/Utils/ilogger.dart';
import 'package:awesome_chewie/src/Utils/itoast.dart';
import 'hive_util.dart';
import 'notification_util.dart';

enum WindowsVersion { installed, portable }

class FileUtil {
  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        lockParentWindow: lockParentWindow,
        onFileLoading: onFileLoading,
        allowCompression: allowCompression,
        compressionQuality: compressionQuality,
        allowMultiple: allowMultiple,
        withData: withData,
        withReadStream: withReadStream,
        readSequential: readSequential,
      );
    } catch (e, t) {
      ILogger.error("Failed to pick files", e, t);
      IToast.showTop(ChewieS.current.pleaseGrantFilePermission);
    }
    return result;
  }

  static Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    String? result;
    try {
      result = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        lockParentWindow: lockParentWindow,
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e, t) {
      ILogger.error("Failed to save file", e, t);
      IToast.showTop(ChewieS.current.pleaseGrantFilePermission);
    }
    return result;
  }

  static Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    bool lockParentWindow = false,
  }) async {
    String? result;
    try {
      result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        lockParentWindow: lockParentWindow,
      );
    } catch (e, t) {
      ILogger.error("Failed to get directory path", e, t);
      IToast.showTop(ChewieS.current.pleaseGrantFilePermission);
    }
    return result;
  }

  static exportLogs({
    bool showLoading = true,
  }) async {
    if (!(await FileOutput.haveLogs())) {
      IToast.showTop(ChewieS.current.noLog);
      return;
    }
    if (ResponsiveUtil.isDesktop()) {
      String? filePath = await FileUtil.saveFile(
        dialogTitle: ChewieS.current.exportLog,
        fileName:
            "Snipet-Logs-${TimeUtil.getFormattedDate(DateTime.now())}.zip",
        type: FileType.custom,
        allowedExtensions: ['zip'],
        lockParentWindow: true,
      );
      if (filePath != null) {
        if (showLoading) {
          CustomLoadingDialog.showLoading(title: ChewieS.current.exporting);
        }
        try {
          Uint8List? data = await FileOutput.getArchiveData();
          if (data != null) {
            File file = File(filePath);
            await file.writeAsBytes(data);
            IToast.showTop(ChewieS.current.exportSuccess);
          } else {
            IToast.showTop(ChewieS.current.exportFailed);
          }
        } catch (e, t) {
          ILogger.error("Failed to zip logs", e, t);
          IToast.showTop(ChewieS.current.exportFailed);
        } finally {
          if (showLoading) {
            CustomLoadingDialog.dismissLoading();
          }
        }
      }
    } else {
      if (showLoading) {
        CustomLoadingDialog.showLoading(title: ChewieS.current.exporting);
      }
      try {
        Uint8List? data = await FileOutput.getArchiveData();
        if (data == null) {
          IToast.showTop(ChewieS.current.exportFailed);
          return;
        }
        String? filePath = await FileUtil.saveFile(
          dialogTitle: ChewieS.current.exportLog,
          fileName:
              "Snipet-Logs-${TimeUtil.getFormattedDate(DateTime.now())}.zip",
          type: FileType.custom,
          allowedExtensions: ['zip'],
          lockParentWindow: true,
          bytes: data,
        );
        if (filePath != null) {
          IToast.showTop(ChewieS.current.exportSuccess);
        }
      } catch (e, t) {
        ILogger.error("Failed to zip logs", e, t);
        IToast.showTop(ChewieS.current.exportFailed);
      } finally {
        if (showLoading) {
          CustomLoadingDialog.dismissLoading();
        }
      }
    }
  }

  static Future<String> getApplicationDir() async {
    final dir = await getApplicationDocumentsDirectory();
    var appName = (await PackageInfo.fromPlatform()).appName;
    if (kDebugMode) {
      appName += "-Debug";
    }
    String path = join(dir.path, appName);
    Directory directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return path;
  }

  static Future<String> getFontDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Fonts"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getBackupDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Backup"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getScreenshotDir() async {
    Directory directory =
        Directory(join(await getApplicationDir(), "Screenshots"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getLogDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Logs"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getCookiesDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Cookies"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getHiveDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Hive"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getDatabaseDir() async {
    Directory directory =
        Directory(join(await getApplicationDir(), "Database"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static String getFileNameWithExtension(String imageUrl) {
    return Uri.parse(imageUrl).pathSegments.last;
  }

  static String getFileExtension(String imageUrl) {
    return getFileNameWithExtension(imageUrl).split('.').last;
  }

  static String getFileName(String imageUrl) {
    return getFileNameWithExtension(imageUrl).split('.').first;
  }

  static String extractFileNameFromUrl(String imageUrl) {
    return Uri.parse(imageUrl).pathSegments.last;
  }

  static String extractFileExtensionFromUrl(String imageUrl) {
    return extractFileNameFromUrl(imageUrl).split('.').last;
  }

  static Future<void> downloadAndUpdate(
    BuildContext context,
    String apkUrl,
    String htmlUrl, {
    String? version,
    bool isUpdate = true,
    Function(double)? onReceiveProgress,
  }) async {
    await Permission.storage.onDeniedCallback(() {
      IToast.showTop("请授予文件存储权限");
    }).onGrantedCallback(() async {
      if (apkUrl.notNullOrEmpty) {
        double progressValue = 0.0;
        var appDocDir = await getTemporaryDirectory();
        String savePath =
            "${appDocDir.path}/${FileUtil.extractFileNameFromUrl(apkUrl)}";
        try {
          await Dio().download(
            apkUrl,
            savePath,
            onReceiveProgress: (count, total) {
              final value = count / total;
              if (progressValue != value) {
                if (progressValue < 1.0) {
                  progressValue = count / total;
                } else {
                  progressValue = 0.0;
                }
                NotificationUtil.sendProgressNotification(
                  0,
                  (progressValue * 100).toInt(),
                  title: isUpdate
                      ? '正在下载新版本安装包...'
                      : '正在下载版本${version ?? ""}的安装包...',
                  payload: version ?? "",
                );
                onReceiveProgress?.call(progressValue);
              }
            },
          ).then((response) async {
            if (response.statusCode == 200) {
              NotificationUtil.closeNotification(0);
              NotificationUtil.sendInfoNotification(
                1,
                "下载完成",
                isUpdate
                    ? "新版本安装包已经下载完成，点击立即安装"
                    : "版本${version ?? ""}的安装包已经下载完成，点击立即安装",
                payload: savePath,
              );
            } else {
              UriUtil.openExternal(htmlUrl);
            }
          });
        } catch (e, t) {
          ILogger.error("Failed to download", e, t);
          NotificationUtil.closeNotification(0);
          NotificationUtil.sendInfoNotification(
            2,
            "下载失败，请重试",
            "新版本安装包下载失败，请重试",
          );
        }
      } else {
        UriUtil.openExternal(htmlUrl);
      }
    }).onPermanentlyDeniedCallback(() {
      IToast.showTop("已拒绝文件存储权限，将跳转到浏览器下载");
      UriUtil.openExternal(apkUrl);
    }).onRestrictedCallback(() {
      IToast.showTop("请授予文件存储权限");
    }).onLimitedCallback(() {
      IToast.showTop("请授予文件存储权限");
    }).onProvisionalCallback(() {
      IToast.showTop("请授予文件存储权限");
    }).request();
  }

  static Future<ShareResultStatus> shareImage(
    BuildContext context,
    String imageUrl, {
    bool showToast = true,
    String? message,
  }) async {
    CachedNetworkImage image = CachedNetworkImage(
      imageUrl: imageUrl,
      filterQuality: FilterQuality.high,
    );
    BaseCacheManager manager = image.cacheManager ?? DefaultCacheManager();
    Map<String, String> headers = image.httpHeaders ?? {};
    File file = await manager.getSingleFile(
      image.imageUrl,
      headers: headers,
    );
    final result = await Share.shareXFiles([XFile(file.path)], text: message);
    if (result.status == ShareResultStatus.success) {
      IToast.showTop("分享成功");
    } else if (result.status == ShareResultStatus.dismissed) {
      IToast.showTop("取消分享");
    } else {
      IToast.showTop("分享失败");
    }
    return result.status;
  }

  static Future<File> getImageFile(
    BuildContext context,
    String imageUrl, {
    bool showToast = true,
  }) async {
    CachedNetworkImage image = CachedNetworkImage(
      imageUrl: imageUrl,
      filterQuality: FilterQuality.high,
    );
    BaseCacheManager manager = image.cacheManager ?? DefaultCacheManager();
    Map<String, String> headers = image.httpHeaders ?? {};
    return await manager.getSingleFile(
      image.imageUrl,
      headers: headers,
    );
  }

  static checkDirectory(String filePath) {
    Directory directory = Directory(dirname(filePath));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  static Future<File> copyAndRenameFile(File file, String newFileName) async {
    String dir = file.parent.path;
    String newPath = '$dir/$newFileName';
    checkDirectory(newPath);
    File copiedFile = await file.copy(newPath);
    await copiedFile.rename(newPath);
    return copiedFile;
  }

  static Future<bool> saveImage(
    BuildContext context,
    String imageUrl, {
    bool showToast = true,
    String? fileName,
  }) async {
    try {
      CachedNetworkImage image = CachedNetworkImage(
        imageUrl: imageUrl,
        filterQuality: FilterQuality.high,
      );
      BaseCacheManager manager = image.cacheManager ?? DefaultCacheManager();
      Map<String, String> headers = image.httpHeaders ?? {};
      File file = await manager.getSingleFile(
        image.imageUrl,
        headers: headers,
      );
      File copiedFile = await copyAndRenameFile(
          file, fileName ?? FileUtil.extractFileNameFromUrl(imageUrl));
      String? saveDirectory =
          ChewieHiveUtil.getString(ChewieHiveUtil.savePathKey);
      if (ResponsiveUtil.isMobile() && saveDirectory.nullOrEmpty) {
        var result = await ImageGallerySaver.saveFile(
          copiedFile.path,
          name: fileName ?? FileUtil.extractFileNameFromUrl(imageUrl),
        );
        bool success = result != null && result['isSuccess'];
        if (showToast) {
          if (success) {
            IToast.showTop("图片已保存至相册");
          } else {
            IToast.showTop("保存失败，请重试");
          }
        }
        return success;
      } else {
        String? saveDirectory = await checkSaveDirectory(context);
        if (saveDirectory.notNullOrEmpty) {
          String newPath =
              '$saveDirectory/${fileName ?? FileUtil.extractFileNameFromUrl(imageUrl)}';
          checkDirectory(newPath);
          await copiedFile.copy(newPath);
          if (showToast) {
            IToast.showTop("图片已保存至$saveDirectory");
          }
          return true;
        } else {
          IToast.showTop("保存失败，请设置图片保存路径");
          return false;
        }
      }
    } catch (e, t) {
      ILogger.error("Failed to save", e, t);
      if (e is PathNotFoundException) {
        IToast.showTop("保存路径不存在");
      } else {
        IToast.showTop("保存失败，请重试");
      }
      return false;
    }
  }

  static Future<bool> saveImages(
    BuildContext context,
    List<String> imageUrls, {
    bool showToast = true,
  }) async {
    try {
      List<bool> statusList = await Future.wait(imageUrls.map((e) async {
        return await saveImage(context, e, showToast: false);
      }).toList());
      bool result = statusList.every((element) => element);
      if (showToast) {
        if (result) {
          String? saveDirectory = await checkSaveDirectory(context);
          if (ResponsiveUtil.isMobile() && saveDirectory.nullOrEmpty) {
            IToast.showTop("所有图片已保存至相册");
          } else {
            IToast.showTop("所有图片已保存至$saveDirectory");
          }
        } else {
          IToast.showTop("保存失败，请重试");
        }
      }
      return result;
    } catch (e, t) {
      ILogger.error("Failed to save", e, t);
      IToast.showTop("保存失败，请重试");
      return false;
    }
  }

  static Future<String?> checkSaveDirectory(BuildContext context) async {
    if (ResponsiveUtil.isDesktop()) {
      String? saveDirectory =
          ChewieHiveUtil.getString(ChewieHiveUtil.savePathKey);
      if (saveDirectory.nullOrEmpty) {
        await Future.delayed(const Duration(milliseconds: 300), () async {
          String? selectedDirectory =
              await FilePicker.platform.getDirectoryPath(
            dialogTitle: "选择图片/视频保存路径",
            lockParentWindow: true,
          );
          if (selectedDirectory != null) {
            saveDirectory = selectedDirectory;
            ChewieHiveUtil.put(ChewieHiveUtil.savePathKey, selectedDirectory);
          }
        });
      }
      if (saveDirectory.notNullOrEmpty) {
        Directory(saveDirectory!).createSync(recursive: true);
      }
      return saveDirectory;
    }
    return ChewieHiveUtil.getString(ChewieHiveUtil.savePathKey);
  }

  static Future<bool> saveVideo(
    BuildContext context,
    String videoUrl, {
    bool showToast = true,
    String? fileName,
    Function(int, int)? onReceiveProgress,
  }) async {
    try {
      var appDocDir = await getTemporaryDirectory();
      String savePath = appDocDir.path + extractFileNameFromUrl(videoUrl);
      await Dio()
          .download(videoUrl, savePath, onReceiveProgress: onReceiveProgress);
      String? saveDirectory =
          ChewieHiveUtil.getString(ChewieHiveUtil.savePathKey);
      if (ResponsiveUtil.isMobile() && saveDirectory.nullOrEmpty) {
        var result = await ImageGallerySaver.saveFile(
          savePath,
          name: fileName ?? FileUtil.extractFileNameFromUrl(videoUrl),
        );
        bool success = result != null && result['isSuccess'];
        if (showToast) {
          if (success) {
            IToast.showTop("视频已保存至相册");
          } else {
            IToast.showTop("保存失败，请重试");
          }
        }
        return success;
      } else {
        String? saveDirectory = await checkSaveDirectory(context);
        if (saveDirectory.notNullOrEmpty) {
          String newPath =
              '$saveDirectory/${fileName ?? FileUtil.extractFileNameFromUrl(videoUrl)}';
          checkDirectory(newPath);
          await File(savePath).copy(newPath);
          if (showToast) {
            IToast.showTop("视频已保存至$saveDirectory");
          }
          return true;
        } else {
          IToast.showTop("保存失败，请设置视频保存路径");
          return false;
        }
      }
    } catch (e, t) {
      ILogger.error("Failed to save", e, t);
      if (e is PathNotFoundException) {
        IToast.showTop("保存路径不存在");
      } else {
        IToast.showTop("保存失败，请重试");
      }
      return false;
    }
  }

  static Future<ReleaseAsset> getAndroidAsset(
      String latestVersion, ReleaseItem item) async {
    ReleaseAsset? resAsset;
    List<ReleaseAsset> assets = item.assets.where((element) {
      return ["application/vnd.android.package-archive", "raw"]
              .contains(element.contentType) &&
          element.name.endsWith(".apk");
    }).toList();
    ReleaseAsset universalAsset = assets.firstWhere((element) {
      return [
        'Snipet-$latestVersion.apk',
        'Snipet-$latestVersion-android-universal.apk'
      ].contains(element.name);
    }, orElse: () => assets.first);
    try {
      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      List<String> supportedAbis =
          androidInfo.supportedAbis.map((e) => e.toLowerCase()).toList();
      ILogger.info("Supported abis: $supportedAbis");
      supportedAbis.sort((a, b) {
        List<String> priorityOrder = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
        int indexA = priorityOrder.indexOf(a);
        int indexB = priorityOrder.indexOf(b);
        indexA = indexA == -1 ? priorityOrder.length : indexA;
        indexB = indexB == -1 ? priorityOrder.length : indexB;
        return indexA.compareTo(indexB);
      });
      ILogger.info("Supported abis after sorted: $supportedAbis");
      for (var asset in assets) {
        String abi =
            asset.name.split("Snipet-$latestVersion-").last.split(".").first;
        for (var supportedAbi in supportedAbis) {
          if (abi.toLowerCase().contains(supportedAbi)) {
            resAsset = asset;
            break;
          }
        }
      }
    } catch (e, t) {
      ILogger.error("Failed to get android info with abis", e, t);
    }
    resAsset ??= universalAsset;
    // if (true) {
    resAsset.pkgsDownloadUrl =
        ChewieUtils.getDownloadUrl(latestVersion, resAsset.name);
    // } else {
    //   resAsset.pkgsDownloadUrl = resAsset.browserDownloadUrl;
    // }
    return resAsset;
  }

  static WindowsVersion checkWindowsVersion(String windowsKeyPath) {
    WindowsVersion tmp = WindowsVersion.portable;

    final key = calloc<IntPtr>();
    final installPathPtr = calloc<Uint16>(260);
    final dataSize = calloc<Uint32>();
    dataSize.value = 260 * 2;

    final result = RegOpenKeyEx(
        HKEY_LOCAL_MACHINE, TEXT(windowsKeyPath), 0, KEY_READ, key);
    if (result == ERROR_SUCCESS) {
      final queryResult = RegQueryValueEx(key.value, TEXT('InstallPath'),
          nullptr, nullptr, installPathPtr.cast(), dataSize);

      if (queryResult == ERROR_SUCCESS) {
        final currentPath = Platform.resolvedExecutable;
        final installPath =
            "${installPathPtr.cast<Utf16>().toDartString()}\\Snipet.exe";
        ILogger.info("Snipet",
            "Get install path: $installPath and current path: $currentPath");
        tmp = installPath == currentPath
            ? WindowsVersion.installed
            : WindowsVersion.portable;
      } else {
        tmp = WindowsVersion.portable;
      }
    }
    RegCloseKey(key.value);
    calloc.free(key);
    calloc.free(installPathPtr);
    calloc.free(dataSize);
    return tmp;
  }

  static ReleaseAsset getWindowsAsset(
      String latestVersion, ReleaseItem item, String windowsKeyPath) {
    final windowsVersion = FileUtil.checkWindowsVersion(windowsKeyPath);
    if (windowsVersion == WindowsVersion.installed) {
      return getWindowsInstallerAsset(latestVersion, item);
    } else {
      return getWindowsPortableAsset(latestVersion, item);
    }
  }

  static ReleaseAsset getWindowsPortableAsset(
      String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return ["application/zip", "application/x-zip-compressed", "raw"]
              .contains(element.contentType) &&
          element.name.contains("windows") &&
          element.name.endsWith(".zip");
    });
    asset.pkgsDownloadUrl =
        ChewieUtils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }

  static ReleaseAsset getWindowsInstallerAsset(
      String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return ["application/x-msdownload", "application/x-msdos-program", "raw"]
              .contains(element.contentType) &&
          element.name.contains("windows") &&
          element.name.endsWith(".exe");
    });
    asset.pkgsDownloadUrl =
        ChewieUtils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }
}
