import 'dart:collection';

import 'package:awesome_chewie/src/Resources/theme.dart';
import 'package:awesome_chewie/src/Utils/System/uri_util.dart';
import 'package:awesome_chewie/src/Utils/constant.dart';
import 'package:awesome_chewie/src/Utils/itoast.dart';
import 'package:awesome_chewie/src/Utils/utils.dart';
import 'package:awesome_chewie/src/Widgets/BottomSheet/bottom_sheet_builder.dart';
import 'package:awesome_chewie/src/Widgets/Item/Button/round_icon_button.dart';
import 'package:awesome_chewie/src/Widgets/Item/Button/round_icon_text_button.dart';
import 'package:awesome_chewie/src/Widgets/Item/General/appbar_wrapper.dart';
import 'package:awesome_chewie/src/generated/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lucide_icons/lucide_icons.dart';

class WebviewScreen extends StatefulWidget {
  const WebviewScreen({
    super.key,
    required this.url,
    required this.processUri,
  });

  final String url;
  final bool processUri;

  @override
  State<WebviewScreen> createState() => _WebviewScreenState();
}

class _WebviewScreenState extends State<WebviewScreen>
    with TickerProviderStateMixin {
  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    allowsLinkPreview: false,
    useOnDownloadStart: true,
  );
  late ContextMenu contextMenu;
  String url = "";
  String title = "";
  bool canPop = true;
  bool showError = false;
  WebResourceError? currentError;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: false),
      onCreateContextMenu: (hitTestResult) async {},
      onHideContextMenu: () {},
      onContextMenuActionItemClicked: (contextMenuItemClicked) async {},
    );
  }

  _buildMoreButtons() {
    return FlutterContextMenu(
      entries: [
        FlutterContextMenuItem(
          ChewieS.current.refresh,
          iconData: Icons.refresh_rounded,
          onPressed: () async {
            webViewController?.reload();
          },
        ),
        FlutterContextMenuItem(
          ChewieS.current.copyLink,
          iconData: Icons.copy_rounded,
          onPressed: () {
            ChewieUtils.copy(context, widget.url);
          },
        ),
        FlutterContextMenuItem(
          ChewieS.current.openWithBrowser,
          iconData: Icons.open_in_browser_rounded,
          onPressed: () {
            UriUtil.openExternal(widget.url);
          },
        ),
        FlutterContextMenuItem(
          ChewieS.current.shareToOtherApps,
          iconData: Icons.share_rounded,
          onPressed: () {
            UriUtil.share(widget.url);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (_, __) {
        showError = false;
        webViewController?.canGoBack().then((canGoBack) {
          webViewController?.goBack();
        });
      },
      child: Scaffold(
        appBar: AppBarWrapper.simple(
          context: context,
          leadingIcon: Icons.close_rounded,
          titleLeftMargin: 10,
          titleRightMargin: 10,
          centerTitle: true,
          title: title,
          actions: [
            RoundIconButton(
              icon: Icon(Icons.more_vert_rounded,
                  color: Theme.of(context).iconTheme.color),
              onPressed: () {
                BottomSheetBuilder.showContextMenu(
                    context, _buildMoreButtons());
              },
            ),
            const SizedBox(width: 5),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialUserScripts: UnmodifiableListView<UserScript>([]),
              initialSettings: settings,
              contextMenu: contextMenu,
              onWebViewCreated: (controller) async {
                webViewController = controller;
              },
              onTitleChanged: (controller, title) {
                setState(() {
                  this.title = title ?? "";
                });
              },
              onLoadStart: (controller, url) async {
                setState(() {
                  this.url = url.toString();
                });
              },
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT);
              },
              onDownloadStartRequest: (controller, url) async {
                IToast.showTop(ChewieS.current.jumpToBrowserDownload);
                Future.delayed(const Duration(milliseconds: 300), () {
                  UriUtil.openExternalUri(url.url);
                });
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url!;
                if (![
                  "http",
                  "https",
                  "file",
                  "chrome",
                  "data",
                  "javascript",
                  "about",
                ].contains(uri.scheme)) {
                  if (await UriUtil.canLaunchUri(uri)) {
                    UriUtil.launchUri(uri);
                    return NavigationActionPolicy.CANCEL;
                  }
                }
                bool processed = widget.processUri
                    ? await UriUtil.processUrl(
                        context,
                        uri.toString(),
                        quiet: true,
                        pass: true,
                      )
                    : false;
                if (processed) return NavigationActionPolicy.CANCEL;
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  this.url = url.toString();
                });
              },
              onReceivedError: (controller, request, error) {
                currentError = error;
                setState(() {});
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                setState(() {
                  this.url = url.toString();
                });
                webViewController!.canGoBack().then((value) => canPop = !value);
              },
              onConsoleMessage: (controller, consoleMessage) {},
            ),
            progress < 1.0
                ? LinearProgressIndicator(
                    value: progress,
                    color: ChewieTheme.primaryColor,
                    backgroundColor: Colors.transparent,
                    minHeight: 2,
                  )
                : emptyWidget,
            _buildErrorPage(),
          ],
        ),
      ),
    );
  }

  _buildErrorPage() {
    return Visibility(
      visible: showError,
      child: Container(
        height: MediaQuery.sizeOf(context).height - 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ChewieTheme.getBackground(context),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: 100),
              Icon(
                LucideIcons.triangleAlert,
                size: 50,
                color: Theme.of(context).iconTheme.color,
              ),
              const SizedBox(height: 10),
              Text(
                ChewieS.current.loadFailed,
                style: ChewieTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                ChewieS.current.loadErrorType(currentError != null
                    ? currentError?.type ?? ""
                    : ChewieS.current.loadUnkownError),
                style: ChewieTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Container(
                width: 180,
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: RoundIconTextButton(
                  text: ChewieS.current.reload,
                  onPressed: () {
                    webViewController?.reload();
                  },
                  fontSizeDelta: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
