import 'package:alist/generated/images.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/named_router.dart';
import 'package:alist/util/user_controller.dart';
import 'package:alist/util/widget_utils.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
        appbarTitle: Text(Intl.screenName_settings.tr),
        body: const _SettingsContainer());
  }
}

class _SettingsContainer extends StatefulWidget {
  const _SettingsContainer({Key? key}) : super(key: key);

  @override
  State<_SettingsContainer> createState() => _SettingsContainerState();
}

class _SettingsContainerState extends State<_SettingsContainer>
    with AutomaticKeepAliveClientMixin {
  final UserController _userController = Get.find();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isDarkMode = WidgetUtils.isDarkMode(context);

    return Obx(() {
      final settingsMenus = _buildSettingsMenuItems();
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemBuilder: (child, index) {
          var settingsMenu = settingsMenus[index];
          return _buildListItem(settingsMenu, context, isDarkMode);
        },
        separatorBuilder: (child, index) {
          return const Divider();
        },
        itemCount: settingsMenus.length,
      );
    });
  }

  ListTile _buildListItem(
      SettingsMenu settingsMenu, BuildContext context, bool isDarkMode) {
    return ListTile(
      onTap: () {
        Get.toNamed(settingsMenu.route);
      },
      horizontalTitleGap: 2,
      tileColor: Theme.of(context).colorScheme.background.withAlpha(125),
      minVerticalPadding: 15,
      leading: settingsMenu.iconData != null
          ? Icon(settingsMenu.iconData)
          : Image.asset(settingsMenu.icon!),
      title: Text(settingsMenu.name),
      trailing: Image.asset(
        Images.iconArrowRight,
        color: isDarkMode ? Colors.white : null,
      ),
    );
  }

  List<SettingsMenu> _buildSettingsMenuItems() {
    final menus = <SettingsMenu>[
      SettingsMenu(
        name: Intl.settingsScreen_item_account.tr,
        icon: Images.settingsScreenAccount,
        route: NamedRouter.account,
      ),
      SettingsMenu(
          name: Intl.settingsScreen_item_downloads.tr,
          icon: Images.settingsScreenDownload,
          route: NamedRouter.downloadManager),
      SettingsMenu(
          name: Intl.settingsScreen_item_cacheManagement.tr,
          icon: Images.settingsScreenCacheManager,
          route: NamedRouter.cacheManager),
      SettingsMenu(
          name: Intl.settingsScreen_item_videoPlayer.tr,
          icon: Images.settingsScreenPlayer,
          route: NamedRouter.playerSettings),
    ];
    if (!_userController.user.value.guest) {
      menus.insert(
        1,
        SettingsMenu(
          name: Intl.settingsScreen_item_shareManager.tr,
          iconData: Icons.share_outlined,
          route: NamedRouter.shareManager,
        ),
      );
    }
    return menus;
  }

  @override
  bool get wantKeepAlive => true;
}

class SettingsMenu {
  final String name;
  final String? icon;
  final IconData? iconData;
  final String route;

  SettingsMenu({
    required this.name,
    this.icon,
    this.iconData,
    required this.route,
  }) : assert(icon != null || iconData != null);
}
