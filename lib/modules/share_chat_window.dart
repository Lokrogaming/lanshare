import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:global_repository/global_repository.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:speed_share/app/controller/chat_controller.dart';
import 'package:speed_share/app/controller/device_controller.dart';
import 'package:speed_share/config/config.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/global/widgets/pop_button.dart';
import 'package:speed_share/themes/app_colors.dart';
import 'package:speed_share/themes/theme.dart';
import 'package:file_manager_view/file_manager_view.dart' as fm;

// 聊天窗口
class ShareChatV2 extends StatefulWidget {
  const ShareChatV2({
    Key? key,
  }) : super(key: key);

  @override
  State createState() => _ShareChatV2State();
}

class _ShareChatV2State extends State<ShareChatV2> with SingleTickerProviderStateMixin {
  ChatController controller = Get.find();
  late AnimationController menuAnim;
  int index = 0;
  // 输入框控制器
  TextEditingController editingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    menuAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    menuAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        left: false,
        child: Column(
          children: [
            if (ResponsiveBreakpoints.of(context).isMobile) appbar(context) else SizedBox(height: 10.w),
            Expanded(
              child: Row(
                children: [
                  if (ResponsiveBreakpoints.of(context).isMobile) leftNav(),
                  chatBody(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Expanded chatBody(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.w),
        child: Column(
          children: [
            Expanded(child: chatList(context)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 64.w, maxHeight: 240.w),
                  child: sendMsgContainer(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  GestureDetector chatList(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller.focusNode.unfocus();
      },
      child: Material(
        borderRadius: BorderRadius.circular(10.w),
        color: Theme.of(context).colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        child: GetBuilder<ChatController>(builder: (context) {
          List<Widget?> children = [];
          if (controller.backup.isNotEmpty) {
            children = controller.backup;
          } else {
            children = controller.children;
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0.w, 0.w, 0.w, 80.w),
            controller: controller.scrollController,
            itemCount: children.length,
            cacheExtent: 99999,
            itemBuilder: (c, i) {
              return (children)[i];
            },
          );
        }),
      ),
    );
  }

  SizedBox leftNav() {
    return SizedBox(
      width: 64.w,
      child: Material(
        child: Column(
          children: [
            SizedBox(height: 4.w),
            LeftNav(value: index),
          ],
        ),
      ),
    );
  }

  Material appbar(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      child: SizedBox(
        height: 48.w,
        child: Row(
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (ResponsiveBreakpoints.of(context).isMobile) const PopButton(),
            SizedBox(width: 12.w),
            Text(
              S.current.allDevices,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: bold,
                    fontSize: 16.w,
                  ),
            ),
            SizedBox(width: 4.w),
            ValueListenableBuilder<bool>(
              valueListenable: controller.connectState,
              builder: (_, value, __) {
                return Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(color: value ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(16.w)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget menu() {
    return AnimatedBuilder(
      animation: menuAnim,
      builder: (c, child) {
        return SizedBox(
          height: 100.w * menuAnim.value,
          child: child,
        );
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 16.w),
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            SizedBox(
              width: 80.w,
              height: 80.w,
              child: InkWell(
                borderRadius: BorderRadius.circular(10.w),
                onTap: () {
                  menuAnim.reverse();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (GetPlatform.isDesktop || GetPlatform.isWeb) {
                      controller.sendFileForBroswerAndDesktop();
                    } else if (GetPlatform.isAndroid) {
                      controller.sendFileForAndroid(
                        useSystemPicker: true,
                      );
                    }
                  });
                },
                child: Tooltip(
                  message: S.current.systemManagerTips,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        size: 36.w,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(height: 4.w),
                      Text(
                        S.current.systemManager,
                        style: TextStyle(
                          color: AppColors.fontColor,
                          fontWeight: bold,
                          fontSize: 12.w,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            if (GetPlatform.isAndroid && !GetPlatform.isWeb)
              Theme(
                data: Theme.of(context),
                child: Builder(builder: (context) {
                  return SizedBox(
                    width: 80.w,
                    height: 80.w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10.w),
                      onTap: () {
                        menuAnim.reverse();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          controller.sendFileForAndroid(
                            context: context,
                          );
                        });
                      },
                      child: Tooltip(
                        message: S.current.inlineManagerTips,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.file_copy,
                              size: 36.w,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(height: 4.w),
                            Text(
                              S.current.inlineManager,
                              style: TextStyle(
                                color: AppColors.fontColor,
                                fontWeight: bold,
                                fontSize: 12.w,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            if (!GetPlatform.isWeb)
              SizedBox(
                width: 80.w,
                height: 80.w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10.w),
                  onTap: () async {
                    menuAnim.reverse();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      controller.sendDir();
                    });
                  },
                  child: Tooltip(
                    message: S.current.inlineManagerTips,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          '${fm.Config.packagePrefix}assets/icon/dir.svg',
                          width: 36.w,
                          height: 36.w,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(height: 4.w),
                        Text(
                          S.current.directory,
                          style: TextStyle(
                            color: AppColors.fontColor,
                            fontWeight: bold,
                            fontSize: 12.w,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget sendMsgContainer(BuildContext context) {
    return GetBuilder<ChatController>(builder: (ctl) {
      return Material(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.w),
          topRight: Radius.circular(12.w),
        ),
        color: colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0.w, 8.w, 8.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      width: double.infinity,
                      child: Center(
                        child: GetBuilder<ChatController>(builder: (_) {
                          return TextField(
                            focusNode: controller.focusNode,
                            controller: controller.controller,
                            autofocus: false,
                            maxLines: 8,
                            minLines: 1,
                            keyboardType: GetPlatform.isDesktop ? TextInputType.text : TextInputType.multiline,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: GetPlatform.isWeb ? 16.w : 10.w,
                                horizontal: 12.w,
                              ),
                              hintText: 'shift+enter 即可换行',
                            ),
                            style: const TextStyle(
                              textBaseline: TextBaseline.ideographic,
                            ),
                            onSubmitted: (_) {
                              if (controller.inputMultiline) {
                                controller.controller.value = TextEditingValue(
                                  text: '${controller.controller.text}\n',
                                  selection: TextSelection.collapsed(
                                    offset: controller.controller.selection.end + 1,
                                  ),
                                );
                                controller.focusNode.requestFocus();
                                return;
                              }
                              controller.sendTextMsg();
                              Future.delayed(const Duration(milliseconds: 100), () {
                                controller.focusNode.requestFocus();
                              });
                            },
                          );
                        }),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureWithScale(
                    onTap: () {
                      if (controller.hasInput) {
                        controller.sendTextMsg();
                      } else {
                        if (menuAnim.isCompleted) {
                          menuAnim.reverse();
                        } else {
                          menuAnim.forward();
                        }
                      }
                    },
                    child: Material(
                      borderRadius: BorderRadius.circular(24.w),
                      // borderOnForeground: true,
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: SizedBox(
                        width: 46.w,
                        height: 46.w,
                        child: AnimatedBuilder(
                          animation: menuAnim,
                          builder: (c, child) {
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateZ(menuAnim.value * pi / 4),
                              child: child,
                            );
                          },
                          child: Icon(
                            controller.hasInput ? Icons.send : Icons.add,
                            size: 20.w,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                ],
              ),
              SizedBox(height: 4.w),
              menu(),
            ],
          ),
        ),
      );
    });
  }
}

class LeftNav extends StatefulWidget {
  const LeftNav({
    Key? key,
    this.value,
  }) : super(key: key);
  final int? value;

  @override
  State<LeftNav> createState() => _LeftNavState();
}

class _LeftNavState extends State<LeftNav> with SingleTickerProviderStateMixin {
  DeviceController deviceController = Get.find();
  ChatController chatController = Get.find();
  late AnimationController controller;
  late Animation offset;
  int? index;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 100,
      ),
    );
    offset = Tween<double>(begin: 0, end: 0).animate(controller);
    index = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String getIcon(int? type) {
    switch (type) {
      case 0:
        return 'assets/icon/phone.png';
      case 1:
        return 'assets/icon/computer.png';
      case 2:
        return 'assets/icon/broswer.png';
      default:
        return 'assets/icon/computer.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: controller,
                builder: (context, c) {
                  return SizedBox(
                    height: offset.value,
                  );
                },
              ),
              Stack(
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: SizedBox(
                      height: 10.w,
                      width: 64.w,
                    ),
                  ),
                  Material(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(12.w),
                    ),
                    child: SizedBox(
                      height: 10.w,
                      width: 64.w,
                    ),
                  ),
                ],
              ),
              Container(
                height: 48.w,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.w),
                    bottomLeft: Radius.circular(12.w),
                  ),
                ),
              ),
              Stack(
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: SizedBox(
                      height: 10.w,
                      width: 60.w,
                    ),
                  ),
                  Material(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12.w),
                    ),
                    child: SizedBox(
                      height: 10.w,
                      width: 60.w,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            SizedBox(
              height: 10.w,
            ),
            MenuButton(
              value: 0,
              enable: index == 0,
              child: Image.asset(
                'assets/icon/all.png',
                width: 24.w,
                height: 24.w,
                package: Config.package,
                color: colorScheme.onSurface,
              ),
              onChange: (value) {
                index = value;
                offset = Tween<double>(begin: offset.value, end: 0.w).animate(controller);
                chatController.restoreList();
                controller.reset();
                controller.forward();
                setState(() {});
              },
            ),
            GetBuilder<DeviceController>(builder: (_) {
              return Column(
                children: [
                  for (int i = 0; i < deviceController.connectDevice.length; i++)
                    MenuButton(
                      value: i + 1,
                      enable: index == i + 1,
                      child: Image.asset(
                        getIcon(deviceController.connectDevice[i].deviceType),
                        width: 32.w,
                        height: 32.w,
                        package: Config.package,
                      ),
                      onChange: (value) {
                        index = value;
                        offset = Tween<double>(
                          begin: offset.value,
                          end: (i + 1) * 60.w,
                        ).animate(controller);
                        controller.reset();
                        controller.forward();
                        chatController.changeListToDevice(
                          deviceController.connectDevice[i],
                        );
                        setState(() {});
                      },
                    ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({
    Key? key,
    this.enable = true,
    this.value,
    this.onChange,
    this.child,
  }) : super(key: key);
  final bool enable;
  final int? value;
  final void Function(int? index)? onChange;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ChatController controller = Get.find();
            controller.focusNode.unfocus();
            onChange?.call(value);
          },
          child: SizedBox(
            width: 60.w,
            child: Padding(
              padding: EdgeInsets.only(
                left: 10.w,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.w),
                  bottomLeft: Radius.circular(10.w),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                      width: 48.w,
                      height: 48.w,
                      child: Center(
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 12.w,
        ),
      ],
    );
  }
}
