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
import 'package:cloudotp/Screens/Setting/base_setting_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class SelectFontScreen extends BaseSettingScreen {
  const SelectFontScreen({super.key});

  static const String routeName = "/setting/font";

  @override
  State<SelectFontScreen> createState() => _SelectFontScreenState();
}

class _SelectFontScreenState extends State<SelectFontScreen>
    with TickerProviderStateMixin {
  CustomFont _currentFont = CustomFont.getCurrentFont();
  List<CustomFont> customFonts = ChewieHiveUtil.getCustomFonts();

  @override
  Widget build(BuildContext context) {
    return ItemBuilder.buildSettingScreen(
      context: context,
      title: S.current.chooseFontFamily,
      showTitleBar: widget.showTitleBar,
      showBack: true,
      padding: widget.padding,
      onTapBack: () {
        if (ResponsiveUtil.isLandscape()) {
          chewieProvider.dialogNavigatorState?.popPage();
        } else {
          Navigator.pop(context);
        }
      },
      children: [
        CaptionItem(
          title: S.current.defaultFontFamily,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
              child: Wrap(
                runSpacing: 10,
                spacing: 10,
                children: _buildDefaultFontList(),
              ),
            ),
          ],
        ),
        CaptionItem(
          title: S.current.customFontFamily,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
              child: Wrap(
                runSpacing: 10,
                spacing: 10,
                children: _buildCustomFontList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  List<Widget> _buildDefaultFontList() {
    var list = List<Widget>.generate(
      CustomFont.defaultFonts.length,
      (index) => FontItem(
        currentFont: _currentFont,
        font: CustomFont.defaultFonts[index],
        onChanged: (_) {
          _currentFont = CustomFont.defaultFonts[index];
          chewieProvider.currentFont = _currentFont;
          CustomFont.loadFont(context, _currentFont, autoRestartApp: false);
        },
      ),
    );
    return list;
  }

  List<Widget> _buildCustomFontList() {
    var list = List<Widget>.generate(
      customFonts.length,
      (index) => FontItem(
        currentFont: _currentFont,
        showDelete: true,
        font: customFonts[index],
        onChanged: (_) {
          _currentFont = customFonts[index];
          chewieProvider.currentFont = _currentFont;
          CustomFont.loadFont(context, customFonts[index],
              autoRestartApp: false);
        },
        onDelete: (_) {
          DialogBuilder.showConfirmDialog(
            context,
            title: S.current.deleteFont(customFonts[index].intlFontName),
            message:
                S.current.deleteFontMessage(customFonts[index].intlFontName),
            onTapConfirm: () async {
              if (customFonts[index] == _currentFont) {
                _currentFont = CustomFont.Default;
                chewieProvider.currentFont = _currentFont;
                CustomFont.loadFont(context, _currentFont,
                    autoRestartApp: false);
              }
              await CustomFont.deleteFont(customFonts[index]);
              customFonts.removeAt(index);
              ChewieHiveUtil.setCustomFonts(customFonts);
            },
          );
        },
      ),
    );
    list.add(
      EmptyFontItem(
        onTap: () async {
          FilePickerResult? result = await FileUtil.pickFiles(
            dialogTitle: S.current.loadFontFamily,
            allowedExtensions: ['ttf', 'otf'],
            lockParentWindow: true,
            type: FileType.custom,
          );
          if (result != null) {
            CustomFont? customFont =
                await CustomFont.copyFont(filePath: result.files.single.path!);
            if (customFont != null) {
              customFonts.add(customFont);
              ChewieHiveUtil.setCustomFonts(customFonts);
              _currentFont = customFont;
              chewieProvider.currentFont = _currentFont;
              CustomFont.loadFont(context, _currentFont, autoRestartApp: false);
              setState(() {});
            } else {
              IToast.showTop(S.current.fontFamlyLoadFailed);
            }
          }
        },
      ),
    );
    return list;
  }
}
