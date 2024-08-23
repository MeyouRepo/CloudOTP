import 'dart:ui';

import 'package:cloudotp/Database/category_dao.dart';
import 'package:cloudotp/Models/opt_token.dart';
import 'package:cloudotp/Screens/Backup/cloud_service_screen.dart';
import 'package:cloudotp/Screens/Setting/about_setting_screen.dart';
import 'package:cloudotp/Screens/Setting/backup_log_screen.dart';
import 'package:cloudotp/Screens/Setting/setting_navigation_screen.dart';
import 'package:cloudotp/Screens/main_screen.dart';
import 'package:cloudotp/Utils/hive_util.dart';
import 'package:cloudotp/Utils/responsive_util.dart';
import 'package:cloudotp/Utils/utils.dart';
import 'package:cloudotp/Widgets/BottomSheet/add_bottom_sheet.dart';
import 'package:cloudotp/Widgets/Custom/marquee_widget.dart';
import 'package:cloudotp/Widgets/Item/item_builder.dart';
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../Database/token_dao.dart';
import '../Models/token_category.dart';
import '../Utils/app_provider.dart';
import '../Utils/asset_util.dart';
import '../Utils/itoast.dart';
import '../Utils/route_util.dart';
import '../Widgets/BottomSheet/bottom_sheet_builder.dart';
import '../Widgets/BottomSheet/input_bottom_sheet.dart';
import '../Widgets/BottomSheet/select_token_bottom_sheet.dart';
import '../Widgets/Custom/custom_tab_indicator.dart';
import '../Widgets/Custom/loading_icon.dart';
import '../Widgets/Dialog/dialog_builder.dart';
import '../Widgets/Hidable/scroll_to_hide.dart';
import '../Widgets/Item/input_item.dart';
import '../Widgets/Scaffold/my_scaffold.dart';
import '../Widgets/WaterfallFlow/reorderable_grid.dart';
import '../Widgets/WaterfallFlow/reorderable_grid_view.dart';
import '../Widgets/WaterfallFlow/sliver_waterfall_flow.dart';
import '../generated/l10n.dart';
import 'Token/category_screen.dart';
import 'Token/token_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  static const String routeName = "/home";

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String appName = "";
  LayoutType layoutType = HiveUtil.getLayoutType();
  OrderType orderType = HiveUtil.getOrderType();
  List<OtpToken> tokens = [];
  List<TokenCategory> categories = [];
  List<Tab> tabList = [];
  int _currentTabIndex = 0;
  String _searchKey = "";
  Map<int, GlobalKey<TokenLayoutState>> tokenKeyMap = {};
  late TabController _tabController;
  ScrollController _scrollController = ScrollController();
  final ScrollController _nestScrollController = ScrollController();
  final ScrollToHideController _scrollToHideController =
      ScrollToHideController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _marqueeController = PageController();
  late AnimationController _animationController;
  final FocusNode _searchFocusNode = FocusNode();
  GridItemsNotifier gridItemsNotifier = GridItemsNotifier();
  final ValueNotifier<bool> _shownSearchbarNotifier = ValueNotifier(false);

  int get currentCategoryId {
    if (_currentTabIndex == 0) {
      return -1;
    } else {
      if (_currentTabIndex - 1 < 0 ||
          _currentTabIndex - 1 >= categories.length) {
        return -1;
      }
      return categories[_currentTabIndex - 1].id;
    }
  }

  @override
  void initState() {
    super.initState();
    initTab(true);
    initAppName();
    refresh(true);
    _searchController.addListener(() {
      performSearch(_searchController.text);
    });
    _animationController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 300),
    );
  }

  initAppName() {
    PackageInfo.fromPlatform().then((info) {
      setState(() {
        appName = info.appName;
      });
    });
  }

  insertToken(
    OtpToken token, {
    bool forceAll = false,
  }) async {
    if (currentCategoryId == -1) {
      if (!forceAll) {
        return;
      }
    } else {
      if (!(await CategoryDao.getCategoryIdsByTokenId(token.id))
          .contains(currentCategoryId)) {
        return;
      }
    }
    int calculateInsertIndex = 0;
    switch (orderType) {
      case OrderType.Default:
        calculateInsertIndex = 0;
        break;
      case OrderType.AlphabeticalASC:
        calculateInsertIndex = tokens.indexWhere(
            (element) => element.issuer.compareTo(token.issuer) > 0);
        break;
      case OrderType.AlphabeticalDESC:
        calculateInsertIndex = tokens.indexWhere(
            (element) => element.issuer.compareTo(token.issuer) < 0);
        break;
      case OrderType.CopyTimesDESC:
        calculateInsertIndex = tokens.indexWhere(
            (element) => element.copyTimes.compareTo(token.copyTimes) < 0);
        break;
      case OrderType.CopyTimesASC:
        calculateInsertIndex = tokens.indexWhere(
            (element) => element.copyTimes.compareTo(token.copyTimes) > 0);
        break;
      case OrderType.LastCopyTimeDESC:
        calculateInsertIndex = tokens.indexWhere((element) =>
            element.lastCopyTimeStamp.compareTo(token.lastCopyTimeStamp) < 0);
        break;
      case OrderType.LastCopyTimeASC:
        calculateInsertIndex = tokens.indexWhere((element) =>
            element.lastCopyTimeStamp.compareTo(token.lastCopyTimeStamp) > 0);
        break;
      case OrderType.CreateTimeDESC:
        calculateInsertIndex = tokens.indexWhere((element) =>
            element.createTimeStamp.compareTo(token.createTimeStamp) < 0);
        break;
      case OrderType.CreateTimeASC:
        calculateInsertIndex = tokens.indexWhere((element) =>
            element.createTimeStamp.compareTo(token.createTimeStamp) > 0);
        break;
    }
    tokens.insert(calculateInsertIndex, token);
    gridItemsNotifier.notifyItemInserted?.call(calculateInsertIndex, () {
      setState(() {});
    });
  }

  updateToken(
    OtpToken token, {
    bool pinnedStateChanged = false,
    bool counterChanged = false,
  }) {
    int updateIndex = tokens.indexWhere((element) => element.id == token.id);
    tokens[updateIndex] = token;
    tokenKeyMap
        .putIfAbsent(token.id, () => GlobalKey())
        .currentState
        ?.updateInfo(counterChanged: counterChanged);
    if (pinnedStateChanged) performSort();
  }

  removeToken(OtpToken token) {
    int removeIndex = tokens.indexWhere((element) => element.id == token.id);
    if (removeIndex != -1) tokens.removeAt(removeIndex);
    gridItemsNotifier.notifyItemRemoved?.call(removeIndex, () {
      setState(() {});
    });
  }

  changeCategoriesForToken(OtpToken token, List<int> unselectedCategoryIds,
      List<int> selectedCategoryIds) {
    if (unselectedCategoryIds.contains(currentCategoryId)) {
      removeToken(token);
    }
    for (var id in unselectedCategoryIds) {
      TokenCategory category =
          categories.firstWhere((element) => element.id == id);
      category.tokenIds.remove(token.id);
    }
    if (selectedCategoryIds.contains(currentCategoryId)) {
      insertToken(token);
    }
    for (var id in selectedCategoryIds) {
      TokenCategory category =
          categories.firstWhere((element) => element.id == id);
      category.tokenIds.add(token.id);
    }
  }

  changeTokensForCategory(TokenCategory category) {
    if (category.id == currentCategoryId && currentCategoryId != -1) {
      getTokens();
    }
  }

  refreshCategories() async {
    await getCategories();
  }

  refresh([bool isInit = false]) async {
    if (!mounted) return;
    await getCategories(isInit);
    await getTokens();
  }

  getTokens() async {
    await CategoryDao.getTokensByCategoryId(
      currentCategoryId,
      searchKey: _searchKey,
    ).then((value) {
      tokens = value;
      performSort();
    });
  }

  getCategories([bool isInit = false]) async {
    int oldId = currentCategoryId;
    await CategoryDao.listCategories().then((value) async {
      categories = value;
      List<int> ids = categories.map((e) => e.id).toList();
      if (!ids.contains(oldId)) {
        _currentTabIndex = 0;
        await getTokens();
      } else {
        _currentTabIndex = ids.indexOf(oldId) + 1;
      }
      initTab(isInit);
      setState(() {});
    });
  }

  initTab([bool isInit = false]) {
    tabList.clear();
    tabList.add(_buildTab(null));
    int categoryId = HiveUtil.getSelectedCategoryId();
    for (var category in categories) {
      tabList.add(_buildTab(category));
      if (category.id == categoryId && isInit) {
        _currentTabIndex = categories.indexOf(category) + 1;
      }
    }
    setState(() {});
    _tabController = TabController(length: tabList.length, vsync: this);
    _tabController.index = _currentTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    return MyScaffold(
      key: homeScaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: ResponsiveUtil.isLandscape()
          ? PreferredSize(
              preferredSize: const Size.fromHeight(54),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _buildTabBar(),
              ),
            )
          : null,
      body: ResponsiveUtil.isLandscape()
          ? _buildMainContent()
          : PopScope(
              canPop: false,
              onPopInvokedWithResult: (_, __) {
                if (mounted && _shownSearchbarNotifier.value) {
                  changeSearchBar(false);
                } else {
                  MoveToBackground.moveTaskToBack();
                }
              },
              child: _buildMobileBody(),
            ),
      bottomNavigationBar: ResponsiveUtil.isLandscape() || categories.isEmpty
          ? null
          : _buildMobileBottombar(),
      floatingActionButton: !ResponsiveUtil.isLandscape() && categories.isEmpty
          ? _buildFloatingActionButton()
          : null,
    );
  }

  _buildMobileBody() {
    return NestedScrollView(
      controller: _nestScrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildMobileAppbar(),
        ];
      },
      body: Builder(
        builder: (context) {
          _scrollController = PrimaryScrollController.of(context);
          return _buildMainContent();
        },
      ),
    );
  }

  changeSearchBar(bool shown) {
    Future.delayed(const Duration(milliseconds: 200), () {
      _shownSearchbarNotifier.value = shown;
    });
    _marqueeController.animateToPage(shown ? 1 : 0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    if (shown) {
      _searchFocusNode.requestFocus();
      _animationController.reverse();
    } else {
      _searchController.clear();
      _searchFocusNode.unfocus();
      _animationController.forward();
    }
  }

  _buildFloatingActionButton([bool scrollTohide = true]) {
    var button = FloatingActionButton(
      heroTag: "Hero-${categories.length}",
      onPressed: () {
        BottomSheetBuilder.showBottomSheet(
          context,
          enableDrag: false,
          (context) => const AddBottomSheet(),
        );
      },
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Theme.of(context).primaryColor,
      child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
    );
    return scrollTohide
        ? ScrollToHide(
            scrollController: _scrollController,
            controller: _scrollToHideController,
            height: kToolbarHeight,
            duration: const Duration(milliseconds: 300),
            hideDirection: Axis.vertical,
            child: button,
          )
        : button;
  }

  getActions(AppProvider provider) {
    return [
      if (provider.showBackupLogButton)
        Container(
          margin: const EdgeInsets.only(right: 5),
          child: ItemBuilder.buildIconButton(
            context: context,
            padding: EdgeInsets.zero,
            icon: Selector<AppProvider, LoadingStatus>(
              selector: (context, appProvider) =>
                  appProvider.autoBackupLoadingStatus,
              builder: (context, autoBackupLoadingStatus, child) => LoadingIcon(
                status: autoBackupLoadingStatus,
                normalIcon: Icon(Icons.history_rounded,
                    color: Theme.of(context).iconTheme.color),
              ),
            ),
            onTap: () {
              RouteUtil.pushCupertinoRoute(context, const BackupLogScreen());
            },
          ),
        ),
      if (provider.canShowCloudBackupButton && provider.showCloudBackupButton)
        Container(
          margin: const EdgeInsets.only(right: 5),
          child: ItemBuilder.buildIconButton(
            context: context,
            icon: Icon(
              Icons.cloud_queue_rounded,
              color: Theme.of(context).iconTheme.color,
            ),
            onTap: () {
              RouteUtil.pushCupertinoRoute(context, const CloudServiceScreen());
            },
          ),
        ),
      if (provider.showLayoutButton)
        Container(
          margin: const EdgeInsets.only(right: 5),
          child: ItemBuilder.buildPopupMenuButton(
            context: context,
            icon: Icon(Icons.dashboard_outlined,
                color: Theme.of(context).iconTheme.color),
            itemBuilder: (context) {
              return ItemBuilder.buildPopupMenuItems(
                context,
                MainScreenState.buildLayoutContextMenuButtons(),
              );
            },
            onSelected: (_) {
              globalNavigatorState?.pop();
            },
          ),
        ),
      if (provider.showSortButton)
        Container(
          margin: const EdgeInsets.only(right: 5),
          child: ItemBuilder.buildPopupMenuButton(
            context: context,
            icon: Icon(Icons.sort_rounded,
                color: Theme.of(context).iconTheme.color),
            itemBuilder: (context) {
              return ItemBuilder.buildPopupMenuItems(
                context,
                MainScreenState.buildSortContextMenuButtons(),
              );
            },
            onSelected: (_) {
              globalNavigatorState?.pop();
            },
          ),
        ),
      ItemBuilder.buildPopupMenuButton(
        context: context,
        icon: Icon(Icons.more_vert_rounded,
            color: Theme.of(context).iconTheme.color),
        itemBuilder: (context) {
          return ItemBuilder.buildPopupMenuItems(
            context,
            GenericContextMenu(
              buttonConfigs: [
                ContextMenuButtonConfig(
                  S.current.category,
                  icon: Icon(Icons.category_outlined,
                      color: Theme.of(context).iconTheme.color),
                  onPressed: () {
                    RouteUtil.pushCupertinoRoute(
                        context, const CategoryScreen());
                  },
                ),
                ContextMenuButtonConfig(
                  S.current.setting,
                  icon: AssetUtil.loadDouble(
                    context,
                    AssetUtil.settingLightIcon,
                    AssetUtil.settingDarkIcon,
                  ),
                  onPressed: () {
                    RouteUtil.pushCupertinoRoute(
                        context, const SettingNavigationScreen());
                  },
                ),
                // ContextMenuButtonConfig(
                //   S.current.cloudType,
                //   icon: const Icon(Icons.cloud_queue_rounded),
                //   onPressed: () {
                //     RouteUtil.pushCupertinoRoute(
                //         context, const CloudServiceScreen());
                //   },
                // ),
                ContextMenuButtonConfig(
                  S.current.about,
                  icon: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo-transparent.png',
                      height: 24,
                      width: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                  onPressed: () {
                    RouteUtil.pushCupertinoRoute(
                        context, const AboutSettingScreen());
                  },
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(width: 5),
    ];
  }

  _buildMobileAppbar() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) => ValueListenableBuilder(
        valueListenable: _shownSearchbarNotifier,
        builder: (context, shownSearchbar, child) =>
            ItemBuilder.buildSliverAppBar(
          context: context,
          floating: provider.hideAppbarWhenScrolling,
          pinned: !provider.hideAppbarWhenScrolling,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: SizedBox(
            height: kToolbarHeight,
            child: MarqueeWidget(
              count: 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        if (!_shownSearchbarNotifier.value) {
                          changeSearchBar(true);
                        }
                      },
                      child: Text(
                        appName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .apply(fontWeightDelta: 2),
                      ),
                    ),
                  );
                } else {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(right: 24),
                      child: Row(
                        children: [
                          ItemBuilder.buildIconButton(
                            context: context,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            onTap: () {
                              changeSearchBar(false);
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InputItem(
                              hint: S.current.searchToken,
                              onSubmit: (text) {
                                performSearch(text);
                              },
                              dense: true,
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              autoPlay: false,
              controller: _marqueeController,
            ),
          ),
          expandedHeight: kToolbarHeight,
          collapsedHeight: kToolbarHeight,
          actions: _shownSearchbarNotifier.value ? [] : getActions(provider),
        ),
      ),
    );
  }

  _buildMobileBottombar({double verticalPadding = 10}) {
    double height = kToolbarHeight + verticalPadding * 2;
    return Selector<AppProvider, bool>(
      selector: (context, provider) => provider.hideBottombarWhenScrolling,
      builder: (context, hideBottombarWhenScrolling, child) => ScrollToHide(
        enabled: hideBottombarWhenScrolling,
        scrollController: _scrollController,
        controller: _scrollToHideController,
        height: height,
        duration: const Duration(milliseconds: 300),
        hideDirection: Axis.vertical,
        child: Stack(
          children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  alignment: Alignment.centerLeft,
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withAlpha(127),
                        blurRadius: Utils.isDark(context) ? 50 : 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(vertical: 5 + verticalPadding)
                      .copyWith(right: 70),
                  child:
                      _buildTabBar(const EdgeInsets.only(left: 10, right: 10)),
                ),
              ),
            ),
            Positioned(
              top: verticalPadding,
              right: 15,
              child: _buildFloatingActionButton(false),
            ),
          ],
        ),
      ),
    );
  }

  _buildMainContent() {
    Widget gridView = Selector<AppProvider, bool>(
      selector: (context, provider) => provider.dragToReorder,
      builder: (context, dragToReorder, child) => Selector<AppProvider, bool>(
        selector: (context, provider) => provider.hideProgressBar,
        builder: (context, hideProgressBar, child) =>
            ReorderableGridView.builder(
          controller: _scrollController,
          gridItemsNotifier: gridItemsNotifier,
          autoScroll: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 10),
          gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: layoutType.maxCrossAxisExtent,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            preferredHeight: layoutType.getHeight(hideProgressBar),
          ),
          dragToReorder: dragToReorder,
          cacheExtent: 9999,
          itemDragEnable: (index) {
            if (tokens[index].pinnedInt == 1) {
              return false;
            }
            return true;
          },
          onReorderStart: (_) {
            _scrollToHideController.hide();
          },
          onReorderEnd: (_, __) {
            _scrollToHideController.show();
          },
          onReorder: (int oldIndex, int newIndex) async {
            final item = tokens.removeAt(oldIndex);
            tokens.insert(newIndex, item);
            for (int i = 0; i < tokens.length; i++) {
              tokens[i].seq = tokens.length - i;
            }
            await TokenDao.updateTokens(tokens, autoBackup: false);
            changeOrderType(type: OrderType.Default, doPerformSort: true);
          },
          proxyDecorator:
              (Widget child, int index, Animation<double> animation) {
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor,
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ).scale(2),
                ],
              ),
              child: child,
            );
          },
          itemCount: tokens.length,
          itemBuilder: (context, index) {
            return TokenLayout(
              key: tokenKeyMap.putIfAbsent(tokens[index].id, () => GlobalKey()),
              token: tokens[index],
              layoutType: layoutType,
            );
          },
        ),
      ),
    );
    Widget body = tokens.isEmpty
        ? ListView(
            controller: _scrollController,
            children: [
              ItemBuilder.buildEmptyPlaceholder(
                  context: context, text: S.current.noToken),
            ],
          )
        : gridView;
    return body;
  }

  _buildTabBar([EdgeInsetsGeometry? padding]) {
    return TabBar(
      controller: _tabController,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      tabs: tabList,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      isScrollable: true,
      dividerHeight: 0,
      padding: padding,
      tabAlignment: TabAlignment.start,
      physics: const ClampingScrollPhysics(),
      labelStyle:
          Theme.of(context).textTheme.titleMedium?.apply(fontWeightDelta: 2),
      unselectedLabelStyle:
          Theme.of(context).textTheme.titleMedium?.apply(color: Colors.grey),
      indicator: CustomTabIndicator(
        borderColor: Theme.of(context).primaryColor,
      ),
      onTap: (index) {
        if (_nestScrollController.hasClients) {
          _nestScrollController.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        }
        _currentTabIndex = index;
        getTokens();
        HiveUtil.setSelectedCategoryId(currentCategoryId);
      },
    );
  }

  _buildTab(TokenCategory? category) {
    // {
    // bool normalUserBold = false,
    // bool sameFontSize = false,
    // double fontSizeDelta = 0,
    // }) {
    // TextStyle normalStyle = Theme.of(context).textTheme.titleLarge!.apply(
    //       color: Colors.grey,
    //       fontSizeDelta: fontSizeDelta - (sameFontSize ? 0 : 1),
    //       fontWeightDelta: normalUserBold ? 0 : -2,
    //     );
    // TextStyle selectedStyle = Theme.of(context).textTheme.titleLarge!.apply(
    //       fontSizeDelta: fontSizeDelta + (sameFontSize ? 0 : 1),
    //     );
    return Tab(
      child: ContextMenuRegion(
        behavior: ResponsiveUtil.isDesktop()
            ? const [ContextMenuShowBehavior.secondaryTap]
            : const [],
        contextMenu: _buildTabContextMenuButtons(category),
        child: GestureDetector(
          onLongPress: () {
            if (category != null) {
              HapticFeedback.lightImpact();
              BottomSheetBuilder.showBottomSheet(
                context,
                (context) => SelectTokenBottomSheet(category: category),
              );
            }
          },
          // child: AnimatedDefaultTextStyle(
          //   style: (category == null
          //           ? _currentTabIndex == 0
          //           : currentCategoryId == category.id)
          //       ? selectedStyle
          //       : normalStyle,
          //   duration: const Duration(milliseconds: 100),
          //   child: Container(
          //     alignment: Alignment.center,
          child: Text(category?.title ?? S.current.allTokens),
        ),
        // ),
        // ),
      ),
    );
  }

  processEditCategory(TokenCategory category) {
    InputValidateAsyncController validateAsyncController =
        InputValidateAsyncController(
      validator: (text) async {
        if (text.isEmpty) {
          return S.current.categoryNameCannotBeEmpty;
        }
        if (text != category.title && await CategoryDao.isCategoryExist(text)) {
          return S.current.categoryNameDuplicate;
        }
        return null;
      },
      controller: TextEditingController(),
    );
    BottomSheetBuilder.showBottomSheet(
      context,
      responsive: true,
      (context) => InputBottomSheet(
        title: S.current.editCategoryName,
        hint: S.current.inputCategory,
        maxLength: 32,
        text: category.title,
        validator: (text) {
          if (text.isEmpty) {
            return S.current.categoryNameCannotBeEmpty;
          }
          return null;
        },
        validateAsyncController: validateAsyncController,
        onValidConfirm: (text) async {
          category.title = text;
          await CategoryDao.updateCategory(category);
          refreshCategories();
        },
      ),
    );
  }

  _buildTabContextMenuButtons(TokenCategory? category) {
    addCategory() async {
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
      BottomSheetBuilder.showBottomSheet(
        context,
        responsive: true,
        (context) => InputBottomSheet(
          title: S.current.addCategory,
          hint: S.current.inputCategory,
          validator: (text) {
            if (text.isEmpty) {
              return S.current.categoryNameCannotBeEmpty;
            }
            return null;
          },
          validateAsyncController: validateAsyncController,
          maxLength: 32,
          onValidConfirm: (text) async {
            await CategoryDao.insertCategory(TokenCategory.title(title: text));
            refreshCategories();
            return true;
          },
        ),
      );
    }

    if (category == null) {
      return GenericContextMenu(
        buttonConfigs: [
          ContextMenuButtonConfig(S.current.addCategory, onPressed: () {
            addCategory();
          }),
        ],
      );
    }
    return GenericContextMenu(
      buttonConfigs: [
        ContextMenuButtonConfig(S.current.editCategoryName, onPressed: () {
          processEditCategory(category);
        }),
        ContextMenuButtonConfig(S.current.editCategoryTokens, onPressed: () {
          BottomSheetBuilder.showBottomSheet(
            context,
            responsive: true,
            (context) => SelectTokenBottomSheet(category: category),
          );
        }),
        ContextMenuButtonConfig.divider(),
        ContextMenuButtonConfig(S.current.addCategory, onPressed: () {
          addCategory();
        }),
        ContextMenuButtonConfig.warning(
          S.current.deleteCategory,
          textColor: Colors.red,
          onPressed: () {
            DialogBuilder.showConfirmDialog(
              context,
              title: S.current.deleteCategory,
              message: S.current.deleteCategoryHint(category.title),
              confirmButtonText: S.current.confirm,
              cancelButtonText: S.current.cancel,
              onTapConfirm: () async {
                await CategoryDao.deleteCategory(category);
                IToast.showTop(S.current.deleteCategorySuccess(category.title));
                refreshCategories();
              },
              onTapCancel: () {},
            );
          },
        ),
      ],
    );
  }

  performSearch(String searchKey) {
    _searchKey = searchKey;
    getTokens();
  }

  changeLayoutType([LayoutType? type]) {
    setState(() {
      if (type != null) {
        layoutType = type;
      } else {
        layoutType = layoutType == LayoutType.values.last
            ? LayoutType.Simple
            : LayoutType.values[layoutType.index + 1];
      }
      HiveUtil.setLayoutType(layoutType);
    });
  }

  changeOrderType({
    bool doPerformSort = true,
    OrderType? type,
  }) {
    setState(() {
      if (type != null) {
        orderType = type;
      } else {
        orderType = orderType == OrderType.CreateTimeASC
            ? OrderType.Default
            : OrderType.values[orderType.index + 1];
      }
      HiveUtil.setOrderType(orderType);
    });
    if (doPerformSort) performSort();
  }

  resetCopyTimesSingle(OtpToken token) {
    int updateIndex = tokens.indexWhere((element) => element.id == token.id);
    tokens[updateIndex].copyTimes = 0;
    tokens[updateIndex].lastCopyTimeStamp = 0;
    if (orderType == OrderType.CopyTimesDESC ||
        orderType == OrderType.CopyTimesASC) {
      performSort();
    }
  }

  resetCopyTimes() {
    for (var element in tokens) {
      element.copyTimes = 0;
    }
    if (orderType == OrderType.CopyTimesDESC ||
        orderType == OrderType.CopyTimesASC) {
      performSort();
    }
  }

  performSort() {
    switch (orderType) {
      case OrderType.Default:
        tokens.sort((a, b) => -a.seq.compareTo(b.seq));
        break;
      case OrderType.AlphabeticalASC:
        tokens.sort((a, b) => a.issuer.compareTo(b.issuer));
        break;
      case OrderType.AlphabeticalDESC:
        tokens.sort((a, b) => -a.issuer.compareTo(b.issuer));
        break;
      case OrderType.CopyTimesDESC:
        tokens.sort((a, b) => -a.copyTimes.compareTo(b.copyTimes));
        break;
      case OrderType.CopyTimesASC:
        tokens.sort((a, b) => a.copyTimes.compareTo(b.copyTimes));
        break;
      case OrderType.LastCopyTimeDESC:
        tokens.sort(
            (a, b) => -a.lastCopyTimeStamp.compareTo(b.lastCopyTimeStamp));
        break;
      case OrderType.LastCopyTimeASC:
        tokens
            .sort((a, b) => a.lastCopyTimeStamp.compareTo(b.lastCopyTimeStamp));
        break;
      case OrderType.CreateTimeDESC:
        tokens.sort((a, b) => -a.createTimeStamp.compareTo(b.createTimeStamp));
        break;
      case OrderType.CreateTimeASC:
        tokens.sort((a, b) => a.createTimeStamp.compareTo(b.createTimeStamp));
        break;
    }
    tokens.sort((a, b) => -a.pinnedInt.compareTo(b.pinnedInt));
    setState(() {});
  }
}

enum LayoutType {
  Simple,
  Compact,
  Tile,
  List;

  double get maxCrossAxisExtent {
    switch (this) {
      case LayoutType.Simple:
        return 250;
      case LayoutType.Compact:
        return 250;
      case LayoutType.Tile:
        return 420;
      case LayoutType.List:
        return 480;
    }
  }

  double getHeight([bool hideProgressBar = false]) {
    switch (this) {
      case LayoutType.Simple:
        return hideProgressBar ? 96 : 110;
      case LayoutType.Compact:
        return hideProgressBar ? 97 : 111;
      case LayoutType.Tile:
        return hideProgressBar ? 101 : 115;
      case LayoutType.List:
        return 60;
    }
  }
}

enum OrderType {
  Default,
  AlphabeticalASC,
  AlphabeticalDESC,
  CopyTimesDESC,
  CopyTimesASC,
  LastCopyTimeDESC,
  LastCopyTimeASC,
  CreateTimeDESC,
  CreateTimeASC;

  String get title {
    switch (this) {
      case OrderType.Default:
        return S.current.defaultOrder;
      case OrderType.AlphabeticalASC:
        return S.current.alphabeticalASCOrder;
      case OrderType.AlphabeticalDESC:
        return S.current.alphabeticalDESCOrder;
      case OrderType.CopyTimesDESC:
        return S.current.copyTimesDESCOrder;
      case OrderType.CopyTimesASC:
        return S.current.copyTimesASCOrder;
      case OrderType.LastCopyTimeDESC:
        return S.current.lastCopyTimeDESCOrder;
      case OrderType.LastCopyTimeASC:
        return S.current.lastCopyTimeASCOrder;
      case OrderType.CreateTimeDESC:
        return S.current.createTimeDESCOrder;
      case OrderType.CreateTimeASC:
        return S.current.createTimeASCOrder;
    }
  }
}

extension LayoutTypeExtension on int {
  LayoutType get layoutType {
    return LayoutType.values[Utils.patchEnum(0, LayoutType.values.length)];
  }
}

extension OrderTypeExtension on int {
  OrderType get orderType {
    return OrderType.values[Utils.patchEnum(0, OrderType.values.length)];
  }
}
