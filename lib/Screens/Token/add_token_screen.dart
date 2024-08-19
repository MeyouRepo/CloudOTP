import 'package:cloudotp/Database/token_dao.dart';
import 'package:cloudotp/Models/opt_token.dart';
import 'package:cloudotp/Models/token_category.dart';
import 'package:cloudotp/Utils/app_provider.dart';
import 'package:cloudotp/Utils/itoast.dart';
import 'package:cloudotp/Utils/responsive_util.dart';
import 'package:cloudotp/Widgets/BottomSheet/bottom_sheet_builder.dart';
import 'package:cloudotp/Widgets/BottomSheet/select_category_bottom_sheet.dart';
import 'package:cloudotp/Widgets/Item/item_builder.dart';
import 'package:cloudotp/Widgets/Scaffold/my_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:group_button/group_button.dart';

import '../../Database/category_dao.dart';
import '../../TokenUtils/check_token_util.dart';
import '../../TokenUtils/token_image_util.dart';
import '../../Utils/utils.dart';
import '../../Widgets/BottomSheet/select_icon_bottom_sheet.dart';
import '../../Widgets/Dialog/dialog_builder.dart';
import '../../Widgets/General/EasyRefresh/easy_refresh.dart';
import '../../Widgets/Item/input_item.dart';
import '../../generated/l10n.dart';

class AddTokenScreen extends StatefulWidget {
  const AddTokenScreen({
    super.key,
    this.token,
  });

  final OtpToken? token;

  static const String routeName = "/token/add";

  @override
  State<AddTokenScreen> createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends State<AddTokenScreen>
    with TickerProviderStateMixin {
  final TextEditingController _issuerController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _counterController = TextEditingController();
  final GroupButtonController _typeController = GroupButtonController();
  final GroupButtonController _digitsController = GroupButtonController();
  final GroupButtonController _algorithmController = GroupButtonController();
  late OtpToken _otpToken;
  bool _isEditing = false;
  bool customedImage = false;

  bool get isSteam =>
      // ignore: unnecessary_null_comparison
      _otpToken != null && _otpToken.tokenType == OtpTokenType.Steam;

  bool get isHotp =>
      // ignore: unnecessary_null_comparison
      _otpToken != null && _otpToken.tokenType == OtpTokenType.HOTP;

  bool get isMotp =>
      // ignore: unnecessary_null_comparison
      _otpToken != null && _otpToken.tokenType == OtpTokenType.MOTP;

  bool get isYandex =>
      // ignore: unnecessary_null_comparison
      _otpToken != null && _otpToken.tokenType == OtpTokenType.Yandex;

  List<TokenCategory> categories = [];
  List<int> selectedCategoryIds = [];
  List<int> oldSelectedCategoryIds = [];

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _otpToken = widget.token!.clone();
      setState(() {
        _isEditing = true;
      });
    } else {
      _otpToken = OtpToken.init();
    }
    _issuerController.text = _otpToken.issuer;
    _accountController.text = _otpToken.account;
    _secretController.text = _otpToken.secret;
    _pinController.text = _otpToken.pin;
    _periodController.text = _otpToken.period.toString();
    _counterController.text = _otpToken.counter.toString();
    _typeController.selectIndex(_otpToken.tokenType.index);
    _digitsController.selectIndex(_otpToken.digits.index);
    _algorithmController.selectIndex(_otpToken.algorithm.index);
    _issuerController.addListener(() {
      _otpToken.issuer = _issuerController.text;
      if (!_isEditing && !customedImage) {
        setState(() {
          _otpToken.imagePath = TokenImageUtil.matchBrandLogo(_otpToken) ?? "";
        });
      }
    });
    _accountController.addListener(() {
      _otpToken.account = _accountController.text;
    });
    _secretController.addListener(() {
      _otpToken.secret = _secretController.text;
    });
    _pinController.addListener(() {
      _otpToken.pin = _pinController.text;
    });
    _periodController.addListener(() {
      _otpToken.periodString = _periodController.text;
    });
    _counterController.addListener(() {
      _otpToken.counterString = _counterController.text;
    });
    getCategories();
  }

  getCategories() async {
    if (!_isEditing) {
      selectedCategoryIds = [];
      oldSelectedCategoryIds = [];
    } else {
      selectedCategoryIds =
          await CategoryDao.getCategoryIdsByTokenId(widget.token!.id);
      oldSelectedCategoryIds = List.from(selectedCategoryIds);
    }
    categories = await CategoryDao.listCategories();
    setState(() {});
  }

  Future<bool> isValid() async {
    return formKey.currentState?.validate() ?? false;
    // bool issuerValid = await _issuerStateController.isValid();
    // bool secretValid = await _secretStateController.isValid();
    // bool pinValid = await _pinStateController.isValid();
    // bool periodValid = await _periodStateController.isValid();
    // bool counterValid = await _counterStateController.isValid();
    // switch (_otpToken.tokenType) {
    //   case OtpTokenType.TOTP:
    //     return issuerValid && secretValid && periodValid;
    //   case OtpTokenType.HOTP:
    //     return issuerValid && secretValid && counterValid;
    //   case OtpTokenType.MOTP:
    //     return issuerValid && secretValid && pinValid;
    //   case OtpTokenType.Yandex:
    //     return issuerValid && secretValid && pinValid;
    //   case OtpTokenType.Steam:
    //     return issuerValid && secretValid;
    //   default:
    //     return false;
    // }
  }

  @override
  Widget build(BuildContext context) {
    return MyScaffold(
      appBar: ItemBuilder.buildAppBar(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        forceShowClose: true,
        leading: Icons.close_rounded,
        onLeadingTap: () {
          if (ResponsiveUtil.isLandscape()) {
            dialogNavigatorState?.popPage();
          } else {
            Navigator.pop(context);
          }
        },
        title: Text(
          _isEditing ? S.current.editToken : S.current.addToken,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.apply(fontWeightDelta: 2),
        ),
        center: true,
        actions: [
          ItemBuilder.buildIconButton(
            context: context,
            icon: Icon(
              Icons.done_rounded,
              color: Theme.of(context).iconTheme.color,
            ),
            onTap: () {
              processDone();
            },
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: EasyRefresh(
        child: _buildBody(),
      ),
    );
  }

  processDone() async {
    if (await isValid()) {
      bool success = false;
      List<int> unselectedCategoryIds = oldSelectedCategoryIds
          .where((element) => !selectedCategoryIds.contains(element))
          .toList();
      List<int> newSelectedCategoryIds = selectedCategoryIds
          .where((element) => !oldSelectedCategoryIds.contains(element))
          .toList();
      try {
        if (_isEditing) {
          widget.token?.copyFrom(_otpToken);
          await TokenDao.updateToken(_otpToken);
        } else {
          await TokenDao.insertToken(_otpToken);
        }
        await CategoryDao.updateCategoriesForToken(
          _otpToken.id,
          unselectedCategoryIds,
          newSelectedCategoryIds,
        );
        success = true;
      } catch (e) {
        IToast.showTop(S.current.saveFailed);
      } finally {
        if (!_isEditing) {
          homeScreenState?.insertToken(_otpToken, forceAll: true);
        } else {
          homeScreenState?.updateToken(_otpToken);
        }
        homeScreenState?.changeCategoriesForToken(
          _otpToken,
          unselectedCategoryIds,
          newSelectedCategoryIds,
        );
        if (success) {
          if (ResponsiveUtil.isLandscape()) {
            dialogNavigatorState?.popPage();
          } else {
            Navigator.pop(context);
          }
        }
      }
    }
  }

  _buildBody() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              _iconInfo(),
              const SizedBox(height: 20),
              _typeInfo(),
              const SizedBox(height: 10),
              _basicInfo(),
              const SizedBox(height: 10),
              if (!isSteam && !isYandex) _advancedInfo(),
              if (!isSteam && !isYandex) const SizedBox(height: 10),
              ..._categoryInfo(),
              const SizedBox(height: 10),
              if (_isEditing) ..._copyTimesInfo(),
              if (_isEditing) ..._deleteButton(),
            ],
          ),
        ),
      ],
    );
  }

  _iconInfo() {
    return Utils.isEmpty(_otpToken.imagePath) && Utils.isEmpty(_otpToken.issuer)
        ? Container(
            constraints: const BoxConstraints(maxWidth: 81),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.grey.withOpacity(0.1), width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.png',
                height: 79,
                width: 79,
                fit: BoxFit.contain,
              ),
            ),
          )
        : ItemBuilder.buildTokenImage(_otpToken);
  }

  _typeInfo() {
    return ItemBuilder.buildContainerItem(
      context: context,
      topRadius: true,
      bottomRadius: true,
      padding: const EdgeInsets.only(right: 10),
      child: ItemBuilder.buildGroupTile(
        context: context,
        // title: S.current.tokenType,
        controller: _typeController,
        buttons: OtpTokenType.toLabels(),
        onSelected: (value, index, isSelected) {
          _otpToken.tokenType = index.otpTokenType;
          _otpToken.digits = index.otpTokenType.defaultDigits;
          _digitsController.selectIndex(_otpToken.digits.index);
          _periodController.text = _otpToken.periodString =
              _otpToken.tokenType.defaultPeriod.toString();
          if (_otpToken.tokenType == OtpTokenType.Yandex) {
            _otpToken.digits = OtpDigits.D8;
            _otpToken.algorithm = OtpAlgorithm.SHA256;
          }
          setState(() {});
        },
      ),
    );
  }

  _basicInfo() {
    return ItemBuilder.buildContainerItem(
      context: context,
      topRadius: true,
      bottomRadius: true,
      padding: const EdgeInsets.only(top: 15, bottom: 5, right: 10),
      child: Column(
        children: [
          InputItem(
            controller: _issuerController,
            textInputAction: TextInputAction.next,
            leadingText: S.current.tokenIssuer,
            leadingType: InputItemLeadingType.text,
            topRadius: true,
            validator: (text) {
              if (text.isEmpty) {
                return S.current.issuerCannotBeEmpty;
              }
              return null;
            },
            hint: S.current.tokenIssuerHint,
            maxLength: 32,
          ),
          InputItem(
            controller: _accountController,
            textInputAction: TextInputAction.next,
            leadingType: InputItemLeadingType.text,
            leadingText: S.current.tokenAccount,
            hint: S.current.tokenAccountHint,
          ),
          InputItem(
            controller: _secretController,
            textInputAction: TextInputAction.next,
            leadingType: InputItemLeadingType.text,
            leadingText: S.current.tokenSecret,
            tailingType: InputItemTailingType.password,
            hint: S.current.tokenSecretHint,
            inputFormatters: [
              RegexInputFormatter.onlyNumberAndLetter,
            ],
            bottomRadius: !isMotp,
            validator: (text) {
              if (text.isEmpty) {
                return S.current.secretCannotBeEmpty;
              }
              if (!CheckTokenUtil.isSecretBase32(text)) {
                return S.current.secretNotBase32;
              }
              return null;
            },
          ),
          Visibility(
            visible: isMotp || isYandex,
            child: InputItem(
              controller: _pinController,
              textInputAction: TextInputAction.next,
              leadingText: S.current.tokenPin,
              leadingType: InputItemLeadingType.text,
              tailingType: InputItemTailingType.password,
              hint: S.current.tokenPinHint,
              maxLength: _otpToken.tokenType.maxPinLength,
              bottomRadius: true,
              validator: (text) {
                if (text.isEmpty) {
                  return S.current.pinCannotBeEmpty;
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  _categoryInfo() {
    return [
      ItemBuilder.buildEntryItem(
        context: context,
        topRadius: true,
        tipWidth: 120,
        title: S.current.autoMatchTokenIcon,
        onTap: () {
          setState(() {
            customedImage = false;
            _otpToken.imagePath =
                TokenImageUtil.matchBrandLogo(_otpToken) ?? "";
          });
        },
      ),
      ItemBuilder.buildEntryItem(
        context: context,
        tipWidth: 300,
        title: S.current.editTokenIcon,
        tip: Utils.isNotEmpty(_otpToken.imagePath) ? _otpToken.imagePath : "",
        onTap: () {
          BottomSheetBuilder.showBottomSheet(
            context,
            responsive: true,
            (context) => SelectIconBottomSheet(
              token: _otpToken,
              onSelected: (path) {
                customedImage = true;
                _otpToken.imagePath = path;
                setState(() {});
              },
            ),
          );
        },
      ),
      ItemBuilder.buildEntryItem(
        context: context,
        tipWidth: 300,
        bottomRadius: true,
        title: S.current.editTokenCategory,
        tipWidget: selectedCategoryIds.isNotEmpty
            ? Wrap(
                spacing: 5,
                runSpacing: 5,
                children: selectedCategoryIds
                    .map(
                      (e) => ItemBuilder.buildRoundButton(
                        context,
                        radius: 6,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        background: Theme.of(context).primaryColor,
                        text: categories
                            .firstWhere((element) => element.id == e)
                            .title,
                      ),
                    )
                    .toList(),
              )
            : null,
        onTap: () {
          BottomSheetBuilder.showBottomSheet(
            context,
            responsive: true,
            (context) => SelectCategoryBottomSheet(
              token: _otpToken,
              isEditingToken: true,
              initialCategoryIds: selectedCategoryIds,
              onCategoryChanged: (selected) {
                selectedCategoryIds = selected;
                setState(() {});
              },
            ),
          );
        },
      ),
    ];
  }

  _advancedInfo() {
    return ItemBuilder.buildContainerItem(
      context: context,
      topRadius: true,
      bottomRadius: true,
      padding: EdgeInsets.only(
          top: 5, bottom: 5, right: !isSteam && !isYandex ? 10 : 0),
      child: Column(
        children: [
          Visibility(
            visible: !isSteam && !isYandex,
            child: ItemBuilder.buildGroupTile(
              context: context,
              title: S.current.tokenDigits,
              controller: _digitsController,
              buttons: OtpDigits.toStrings(),
              onSelected: (value, index, isSelected) {
                _otpToken.digits = OtpDigits.froMString(value);
                setState(() {});
              },
            ),
          ),
          Visibility(
            visible: !isSteam && !isMotp && !isYandex,
            child: ItemBuilder.buildGroupTile(
              context: context,
              title: S.current.tokenAlgorithm,
              controller: _algorithmController,
              buttons: OtpAlgorithm.toStrings(),
              onSelected: (value, index, isSelected) {
                _otpToken.algorithm = index.otpAlgorithm;
                setState(() {});
              },
            ),
          ),
          Visibility(
            visible: !isSteam && !isYandex && !isHotp,
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              child: InputItem(
                controller: _periodController,
                leadingText: S.current.tokenPeriod,
                keyboardType: TextInputType.number,
                inputFormatters: [RegexInputFormatter.onlyNumber],
                leadingType: InputItemLeadingType.text,
                textInputAction: _otpToken.tokenType == OtpTokenType.TOTP
                    ? TextInputAction.done
                    : TextInputAction.next,
                hint: S.current.tokenPeriodHint,
                validator: (text) {
                  if (text.isEmpty) {
                    return S.current.periodCannotBeEmpty;
                  }
                  if (int.tryParse(text) == null) {
                    return S.current.periodTooLong;
                  }
                  return null;
                },
              ),
            ),
          ),
          Visibility(
            visible: !isSteam && !isYandex && isHotp,
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              child: InputItem(
                controller: _counterController,
                leadingText: S.current.tokenCounter,
                inputFormatters: [RegexInputFormatter.onlyNumber],
                leadingType: InputItemLeadingType.text,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                bottomRadius: true,
                hint: S.current.tokenCounterHint,
                validator: (text) {
                  if (text.isEmpty) {
                    return S.current.counterCannotBeEmpty;
                  }
                  if (int.tryParse(text) == null) {
                    return S.current.counterTooLong;
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  _copyTimesInfo() {
    return [
      ItemBuilder.buildEntryItem(
        context: context,
        tipWidth: 300,
        topRadius: true,
        title: S.current.resetCopyTimes,
        tip: S.current.currentCopyTimes(_otpToken.copyTimes),
        onTap: () {
          DialogBuilder.showConfirmDialog(
            context,
            title: S.current.resetCopyTimesTitle,
            message: S.current.resetCopyTimesMessage(_otpToken.title),
            onTapConfirm: () async {
              await TokenDao.resetSingleTokenCopyTimes(_otpToken);
              homeScreenState?.resetCopyTimesSingle(_otpToken);
              IToast.showTop(S.current.resetSuccess);
              setState(() {});
            },
            onTapCancel: () {},
          );
        },
      ),
      ItemBuilder.buildEntryItem(
        context: context,
        tipWidth: 300,
        bottomRadius: true,
        title: S.current.lastCopyTime,
        tip: _otpToken.lastCopyTimeStamp == 0
            ? S.current.neverCopied
            : Utils.timestampToDateString(_otpToken.lastCopyTimeStamp),
        onTap: () {},
      ),
    ];
  }

  _deleteButton() {
    return [
      if ((!isSteam && !isYandex) || _isEditing) const SizedBox(height: 30),
      Row(
        children: [
          const SizedBox(width: 30),
          Expanded(
            child: ItemBuilder.buildRoundButton(
              context,
              background: Colors.red,
              text: S.current.deleteToken,
              fontSizeDelta: 2,
              onTap: () {
                DialogBuilder.showConfirmDialog(
                  context,
                  title: S.current.deleteTokenTitle(_otpToken.title),
                  message: S.current.deleteTokenMessage(_otpToken.title),
                  onTapConfirm: () async {
                    await TokenDao.deleteToken(_otpToken);
                    dialogNavigatorState?.popPage();
                    IToast.showTop(
                        S.current.deleteTokenSuccess(_otpToken.title));
                    homeScreenState?.removeToken(_otpToken);
                  },
                  onTapCancel: () {},
                );
              },
            ),
          ),
          const SizedBox(width: 30),
        ],
      ),
      const SizedBox(height: 20),
    ];
  }
}
