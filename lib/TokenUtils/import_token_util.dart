import 'dart:io';

import 'package:cloudotp/Database/token_dao.dart';
import 'package:cloudotp/Models/opt_token.dart';
import 'package:cloudotp/TokenUtils/Backup/backup_encrypt_old.dart';
import 'package:cloudotp/TokenUtils/otp_token_parser.dart';
import 'package:cloudotp/Utils/app_provider.dart';
import 'package:cloudotp/Utils/itoast.dart';
import 'package:cloudotp/Utils/responsive_util.dart';
import 'package:cloudotp/Widgets/Dialog/custom_dialog.dart';
import 'package:cloudotp/Widgets/Dialog/progress_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import '../Database/category_dao.dart';
import '../Database/config_dao.dart';
import '../Models/token_category.dart';
import '../Utils/constant.dart';
import '../Utils/file_util.dart';
import '../Utils/utils.dart';
import '../Widgets/BottomSheet/bottom_sheet_builder.dart';
import '../Widgets/BottomSheet/input_bottom_sheet.dart';
import '../Widgets/BottomSheet/token_option_bottom_sheet.dart';
import '../Widgets/Item/input_item.dart';
import '../generated/l10n.dart';
import 'Backup/backup.dart';
import 'Backup/backup_encrypt_interface.dart';
import 'Backup/backup_encrypt_v1.dart';

class ImportAnalysis {
  int parseFailed;

  int parseSuccess;

  int importSuccess;

  int parseCategorySuccess;

  int importCategorySuccess;

  int importConfigSuccess;

  int importCloudServiceConfigSuccess;

  ImportAnalysis({
    this.parseFailed = 0,
    this.parseSuccess = 0,
    this.importSuccess = 0,
    this.parseCategorySuccess = 0,
    this.importCategorySuccess = 0,
    this.importConfigSuccess = 0,
    this.importCloudServiceConfigSuccess = 0,
  });

  showToast([String noTokenToast = ""]) {
    String tokenToast = S.current.importResultTip(parseSuccess, importSuccess);
    String categoryToast = S.current
        .importCategoryResultTip(parseCategorySuccess, importCategorySuccess);
    if (parseSuccess > 0) {
      if (parseCategorySuccess > 0) {
        IToast.showTop("$tokenToast; $categoryToast");
      } else {
        IToast.showTop(tokenToast);
      }
    } else if (parseCategorySuccess > 0) {
      IToast.showTop(categoryToast);
    } else {
      if (Utils.isNotEmpty(noTokenToast)) {
        IToast.showTop(noTokenToast);
      }
    }
  }
}

class ImportTokenUtil {
  static Future<List<dynamic>> parseRawUri(
    List<String> rawUris, {
    bool autoPopup = true,
    BuildContext? context,
  }) async {
    List<OtpToken> tokens = [];
    List<TokenCategory> categories = [];
    List<String> validTokenUris = [];
    List<String> validCategoryUris = [];
    for (String line in rawUris) {
      Uri? uri = Uri.tryParse(line);
      if (uri != null &&
          (otpauthReg.hasMatch(line) ||
              motpReg.hasMatch(line) ||
              otpauthMigrationReg.hasMatch(line) ||
              cloudotpauthMigrationReg.hasMatch(line))) {
        validTokenUris.add(line);
      }
      if (uri != null && cloudotpauthCategoryMigrationReg.hasMatch(line)) {
        validCategoryUris.add(line);
      }
    }
    if (validTokenUris.isNotEmpty) {
      tokens = await ImportTokenUtil.importText(
        validTokenUris.join("\n"),
        noTokenToast: S.current.imageDoesNotContainToken,
      );
      if (autoPopup && context != null && context.mounted) {
        Navigator.pop(context);
      }
    }
    if (validCategoryUris.isNotEmpty) {
      categories = await ImportTokenUtil.parseCategories(validCategoryUris);
      if (autoPopup && context != null && context.mounted) {
        Navigator.pop(context);
      }
    }
    if (tokens.isEmpty && categories.isEmpty) {
      IToast.showTop(S.current.noQrCodeToken);
    }
    return [tokens, categories];
  }

  static Future<List<dynamic>> analyzeImageFile(
    String filepath, {
    required BuildContext context,
    bool showLoading = true,
  }) async {
    List<dynamic> res = [];
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.analyzing);
    }
    try {
      File file = File(filepath);
      Uint8List? imageBytes = await compute<String, Uint8List?>((path) {
        return File(path).readAsBytesSync();
      }, filepath);
      String fileName = FileUtil.extractFileNameFromUrl(file.path);
      if (ResponsiveUtil.isAndroid()) {
        await File("/storage/emulated/0/Pictures/$fileName")
            .delete(recursive: true);
        await file.delete(recursive: true);
      }
      res = await ImportTokenUtil.analyzeImage(imageBytes,
          context: context, showLoading: false);
    } finally {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
    }
    return res;
  }

  static Future<List<dynamic>> analyzeImage(
    Uint8List? imageBytes, {
    required BuildContext context,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.analyzing);
    }
    List<OtpToken> tokens = [];
    List<TokenCategory> categories = [];
    if (imageBytes == null || imageBytes.isEmpty) {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
      IToast.showTop(S.current.noQrCode);
      return [];
    }
    try {
      var result = await compute((bytes) {
        img.Image image = img.decodeImage(bytes)!;
        LuminanceSource source = RGBLuminanceSource(
            image.width,
            image.height,
            image
                .convert(numChannels: 4)
                .getBytes(order: img.ChannelOrder.abgr)
                .buffer
                .asInt32List());
        var bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
        var reader = QRCodeReader();
        return reader.decode(bitmap);
      }, imageBytes);
      if (Utils.isNotEmpty(result.text)) {
        List<dynamic> res = await ImportTokenUtil.parseRawUri([result.text]);
        tokens = res[0];
        categories = res[1];
      } else {
        IToast.showTop(S.current.noQrCode);
      }
    } catch (e) {
      if (e.runtimeType == NotFoundException) {
        IToast.showTop(S.current.noQrCode);
      } else {
        IToast.showTop(S.current.parseQrCodeWrong);
      }
    } finally {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
    }
    if (tokens.length == 1) {
      BottomSheetBuilder.showBottomSheet(
        context,
        responsive: true,
        (context) => TokenOptionBottomSheet(
          token: tokens.first,
          forceShowCode: true,
        ),
      );
    }
    return [tokens, categories];
  }

  static importUriFile(
    String filePath, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.importing);
    }
    try {
      File file = File(filePath);
      if (!file.existsSync()) {
        IToast.showTop(S.current.fileNotExist);
        return;
      } else {
        String content = file.readAsStringSync();
        await importText(
          content,
          showLoading: showLoading,
          emptyTip: S.current.fileEmpty,
          noTokenToast: S.current.fileDoesNotContainToken,
        );
      }
    } catch (e) {
      IToast.showTop(S.current.importFailed);
    } finally {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
    }
  }

  static Future<bool> importOldEncryptFile(
    String filePath,
    String password, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.importing);
    }
    try {
      File file = File(filePath);
      if (!file.existsSync()) {
        IToast.showTop(S.current.fileNotExist);
        return true;
      } else {
        List<OtpToken>? tokens = await compute((_) async {
          Uint8List content = file.readAsBytesSync();
          List<OtpToken>? tokens =
              await BackupEncryptionOld().decrypt(content, password);
          return tokens;
        }, null);
        if (tokens == null) {
          IToast.showTop(S.current.importFailed);
          return true;
        }
        ImportAnalysis analysis = ImportAnalysis();
        analysis.parseSuccess = tokens.length;
        analysis.importSuccess = await mergeTokens(tokens);
        if (showLoading) {
          CustomLoadingDialog.dismissLoading();
        }
        analysis.showToast(S.current.fileDoesNotContainToken);
        return true;
      }
    } catch (e) {
      IToast.showTop(S.current.importFailed);
      return false;
    } finally {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
    }
  }

  static Future<bool> importEncryptFile(
    String filePath,
    String password, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.importing);
    }
    try {
      File file = File(filePath);
      if (!file.existsSync()) {
        IToast.showTop(S.current.fileNotExist);
        return true;
      } else {
        Uint8List content = await compute((_) async {
          return file.readAsBytesSync();
        }, null);
        await importUint8List(content, password: password);
        return true;
      }
    } catch (e) {
      if (e is BackupBaseException) {
        IToast.showTop(e.intlMessage);
        if (e is InvalidPasswordOrDataCorruptedException) {
          return false;
        }
        return true;
      } else {
        IToast.showTop(S.current.importFailed);
        return true;
      }
    } finally {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
    }
  }

  static Future<bool> importBackupFile(
    Uint8List content, {
    String? password,
    bool showLoading = true,
    String? loadingText,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(
          title: loadingText ?? S.current.importing);
    }
    try {
      await importUint8List(content, password: password);
      return true;
    } catch (e) {
      if (e is BackupBaseException) {
        IToast.showTop(e.intlMessage);
        if (e is InvalidPasswordOrDataCorruptedException) {
          return false;
        }
        return true;
      } else {
        IToast.showTop(S.current.importFailed);
        return true;
      }
    } finally {
      if (showLoading) {
        CustomLoadingDialog.dismissLoading();
      }
    }
  }

  static Future<bool> importUint8List(
    Uint8List content, {
    String? password,
  }) async {
    String tmpPassword = password ?? await ConfigDao.getBackupPassword();
    Backup backup = await compute((_) async {
      return await BackupEncryptionV1().decrypt(content, tmpPassword);
    }, null);
    ImportAnalysis analysis = ImportAnalysis();
    analysis.parseSuccess = backup.tokens.length;
    analysis.parseCategorySuccess = backup.categories.length;
    analysis.importSuccess = await mergeTokens(backup.tokens);
    analysis.importCategorySuccess = await mergeCategories(backup.categories);
    analysis.showToast(S.current.fileDoesNotContainToken);
    return true;
  }

  static Future<List<OtpToken>> importText(
    String content, {
    String emptyTip = "",
    String noTokenToast = "",
    bool showLoading = true,
  }) async {
    if (Utils.isEmpty(content) && Utils.isNotEmpty(emptyTip)) {
      IToast.showTop(emptyTip);
      return [];
    }
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.importing);
    }
    ImportAnalysis analysis = ImportAnalysis();
    List<String> lines = content.split("\n");
    List<OtpToken> tokens = [];
    for (String line in lines) {
      List<OtpToken> parsedTokens = OtpTokenParser.parseUri(line);
      if (parsedTokens.isNotEmpty) {
        tokens.addAll(parsedTokens);
        analysis.parseSuccess += parsedTokens.length;
      } else {
        analysis.parseFailed++;
      }
    }
    analysis.importSuccess = await mergeTokens(tokens);
    if (showLoading) {
      CustomLoadingDialog.dismissLoading();
    }
    analysis.showToast(noTokenToast);
    return tokens;
  }

  static Future<List<TokenCategory>> parseCategories(List<String> lines) async {
    List<TokenCategory> categories = [];
    ImportAnalysis analysis = ImportAnalysis();
    for (var line in lines) {
      List<TokenCategory> tmp =
          await OtpTokenParser.parseCloudOtpauthCategoryMigration(line);
      categories.addAll(tmp);
    }
    analysis.parseCategorySuccess = categories.length;
    analysis.importCategorySuccess = await mergeCategories(categories);
    print(analysis);
    analysis.showToast();
    return categories;
  }

  static bool contain(OtpToken token, List<OtpToken> tokenList) {
    for (OtpToken otpToken in tokenList) {
      if (otpToken.issuer == token.issuer &&
          otpToken.account == token.account) {
        return true;
      }
    }
    return false;
  }

  static bool containCategory(
    TokenCategory category,
    List<TokenCategory> categoryList,
  ) {
    for (TokenCategory tokenCategory in categoryList) {
      if (tokenCategory.title == category.title) {
        return true;
      }
    }
    return false;
  }

  static Future<int> mergeTokens(
    List<OtpToken> tokenList, {
    bool performInsert = true,
  }) async {
    List<OtpToken> already = await TokenDao.listTokens();
    List<OtpToken> newTokenList = [];
    for (OtpToken otpToken in tokenList) {
      if (!contain(otpToken, already) && !contain(otpToken, newTokenList)) {
        newTokenList.add(otpToken);
      }
    }
    if (performInsert) {
      await TokenDao.insertTokens(newTokenList);
      homeScreenState?.refresh();
    }
    return newTokenList.length;
  }

  static Future<int> mergeCategories(
    List<TokenCategory> categoryList, {
    bool performInsert = true,
  }) async {
    List<TokenCategory> already = await CategoryDao.listCategories();
    List<TokenCategory> newCategoryList = [];
    for (TokenCategory category in categoryList) {
      if (!containCategory(category, already) &&
          !containCategory(category, newCategoryList)) {
        newCategoryList.add(category);
      }
    }
    if (performInsert) {
      await CategoryDao.insertCategories(newCategoryList);
      homeScreenState?.refresh();
    }
    return newCategoryList.length;
  }

  static importFromCloud(
    BuildContext context,
    Uint8List? res,
    ProgressDialog dialog,
  ) async {
    dialog.updateMessage(
      msg: S.current.importing,
      showProgress: false,
    );
    if (res == null) {
      dialog.dismiss();
      IToast.showTop(S.current.webDavPullFailed);
      return;
    }
    bool success = await ImportTokenUtil.importBackupFile(
      res,
      showLoading: false,
    );
    dialog.dismiss();
    if (!success) {
      InputValidateAsyncController validateAsyncController =
          InputValidateAsyncController(
        listen: false,
        validator: (text) async {
          if (text.isEmpty) {
            return S.current.autoBackupPasswordCannotBeEmpty;
          }
          dialog.show(
            msg: S.current.importing,
            showProgress: false,
          );
          bool success = await ImportTokenUtil.importBackupFile(
            password: text,
            res,
            showLoading: false,
          );
          dialog.dismiss();
          if (success) {
            return null;
          } else {
            return S.current.invalidPasswordOrDataCorrupted;
          }
        },
        controller: TextEditingController(),
      );
      BottomSheetBuilder.showBottomSheet(
        context,
        responsive: true,
        (context) => InputBottomSheet(
          validator: (value) {
            if (value.isEmpty) {
              return S.current.autoBackupPasswordCannotBeEmpty;
            }
            return null;
          },
          checkSyncValidator: false,
          validateAsyncController: validateAsyncController,
          title: S.current.inputImportPasswordTitle,
          message: S.current.inputImportPasswordTip,
          hint: S.current.inputImportPasswordHint,
          inputFormatters: [
            RegexInputFormatter.onlyNumberAndLetter,
          ],
          tailingType: InputItemTailingType.password,
          onValidConfirm: (password) async {},
        ),
      );
    }
  }
}
