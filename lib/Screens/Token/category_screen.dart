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
import 'package:cloudotp/Utils/app_provider.dart';
import 'package:cloudotp/Widgets/BottomSheet/select_token_bottom_sheet.dart';
import 'package:flutter/material.dart';

import '../../Database/category_dao.dart';
import '../../Models/token_category.dart';
import '../../generated/l10n.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
  });

  static const String routeName = "/token/category";

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with TickerProviderStateMixin {
  List<TokenCategory> categories = [];

  @override
  void initState() {
    super.initState();
    getCategories();
  }

  getCategories() async {
    await CategoryDao.listCategories().then((value) {
      setState(() {
        categories = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyScaffold(
      appBar: ResponsiveAppBar(
        title: S.current.category,
        showBack: !ResponsiveUtil.isLandscape(),
        titleLeftMargin: ResponsiveUtil.isLandscape() ? 15 : 5,
        actions: [
          CircleIconButton(
            icon: Icon(Icons.add_rounded,
                color: Theme.of(context).iconTheme.color),
            onTap: () {
              InputValidateAsyncController validateAsyncController =
                  InputValidateAsyncController(
                validator: (text) async {
                  if (text.isEmpty) {
                    return S.current.categoryNameCannotBeEmpty;
                  }
                  if (await CategoryDao.isCategoryExist(text)) {
                    return S.current.categoryNameDuplicate;
                  }
                  return null;
                },
                controller: TextEditingController(),
              );
              GlobalKey<InputBottomSheetState> key = GlobalKey();
              BottomSheetBuilder.showBottomSheet(context,
                  responsive: true, useWideLandscape: true, (context) {
                return InputBottomSheet(
                  key: key,
                  title: S.current.addCategory,
                  hint: S.current.inputCategory,
                  validateAsyncController: validateAsyncController,
                  style: InputItemStyle(
                    maxLength: 32,
                  ),
                  onValidConfirm: (text) async {
                    TokenCategory category = TokenCategory.title(title: text);
                    await CategoryDao.insertCategory(category);
                    categories.add(category);
                    setState(() {});
                    homeScreenState?.refreshCategories();
                  },
                );
              });
            },
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: _buildBody(),
    );
  }

  _buildBody() {
    return EasyRefresh(
      child: categories.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                EmptyPlaceholder(text: S.current.noCategory),
              ],
            )
          : ReorderableListView.builder(
              itemBuilder: (context, index) {
                return _buildCategoryItem(categories[index]);
              },
              cacheExtent: 9999,
              padding: const EdgeInsets.only(
                  top: 6, left: 12, right: 12, bottom: 30),
              buildDefaultDragHandles: false,
              itemCount: categories.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                TokenCategory oldCategory = categories[oldIndex];
                categories.removeAt(oldIndex);
                categories.insert(newIndex, oldCategory);
                for (int i = 0; i < categories.length; i++) {
                  categories[i].seq = i;
                }
                CategoryDao.updateCategories(categories, backup: true);
                setState(() {});
                homeScreenState?.refreshCategories();
              },
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                return Container(
                  decoration: BoxDecoration(
                    boxShadow: ChewieTheme.defaultBoxShadow,
                  ),
                  child: child,
                );
              },
            ),
    );
  }

  _buildCategoryItem(TokenCategory category) {
    return Container(
      key: ValueKey("${category.id}${category.title}"),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: ChewieDimens.borderRadius8,
        // border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: categories.indexOf(category),
            child: CircleIconButton(
              icon: const Icon(Icons.dehaze_rounded, size: 20),
              onTap: () {},
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              category.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          CircleIconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onTap: () {
              InputValidateAsyncController validateAsyncController =
                  InputValidateAsyncController(
                validator: (text) async {
                  if (text.isEmpty) {
                    return S.current.categoryNameCannotBeEmpty;
                  }
                  if (text != category.title &&
                      await CategoryDao.isCategoryExist(text)) {
                    return S.current.categoryNameDuplicate;
                  }
                  return null;
                },
                controller: TextEditingController(),
              );
              BottomSheetBuilder.showBottomSheet(
                context,
                responsive: true,
                useWideLandscape: true,
                (context) => InputBottomSheet(
                  title: S.current.editCategoryName,
                  hint: S.current.inputCategory,
                  style: InputItemStyle(
                    maxLength: 32,
                  ),
                  text: category.title,
                  validateAsyncController: validateAsyncController,
                  onValidConfirm: (text) async {
                    category.title = text;
                    await CategoryDao.updateCategory(category);
                    setState(() {});
                    homeScreenState?.refreshCategories();
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          CircleIconButton(
            icon: const Icon(Icons.checklist_rounded, size: 20),
            onTap: () {
              BottomSheetBuilder.showBottomSheet(
                context,
                responsive: true,
                (context) => SelectTokenBottomSheet(category: category),
              );
            },
          ),
          const SizedBox(width: 5),
          CircleIconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: Colors.red),
            onTap: () {
              DialogBuilder.showConfirmDialog(
                context,
                title: S.current.deleteCategory,
                message: S.current.deleteCategoryHint(category.title),
                confirmButtonText: S.current.confirm,
                cancelButtonText: S.current.cancel,
                onTapConfirm: () async {
                  await CategoryDao.deleteCategory(category);
                  IToast.showTop(
                      S.current.deleteCategorySuccess(category.title));
                  categories.remove(category);
                  setState(() {});
                  homeScreenState?.refreshCategories();
                },
                onTapCancel: () {},
              );
            },
          ),
        ],
      ),
    );
  }
}
