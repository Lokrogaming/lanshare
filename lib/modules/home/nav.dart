import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/utils.dart';
import 'package:global_repository/global_repository.dart';
import 'package:speed_share/config/config.dart';
import 'package:speed_share/app/routes/page_route_builder.dart';
import 'package:speed_share/themes/app_colors.dart';

import '../send_file_bottom_sheet.dart';

class Nav extends StatefulWidget {
  const Nav({Key? key, this.value, this.onTap}) : super(key: key);
  final int? value;
  final void Function(int value)? onTap;

  @override
  State<Nav> createState() => _NavState();
}

class _NavState extends State<Nav> {
  @override
  Widget build(BuildContext context) {
    Widget center = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.w),
            color: Theme.of(context).primaryColor,
          ),
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..rotateZ(pi / 4),
          width: 36.w,
          height: 36.w,
        ),
        Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 28.w,
          ),
        ),
      ],
    );
    return SizedBox(
      height: 56.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          BottomTab(
            onChange: (value) {
              value = min(value, 4);
              widget.onTap?.call(value);
              setState(() {});
            },
            children: [
              Builder(builder: (context) {
                bool enable = widget.value == 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      enable ? 'assets/icon/homev2_sel.png' : 'assets/icon/homev2.png',
                      width: 24.w,
                      height: 24.w,
                      color: enable ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
                      package: Config.package,
                      gaplessPlayback: false,
                    ),
                  ],
                );
              }),
              if (GetPlatform.isWeb) const SizedBox(),
              Builder(builder: (context) {
                bool enable = widget.value == 1;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icon/remote_file.png',
                      width: 24.w,
                      height: 24.w,
                      color: enable ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
                      gaplessPlayback: false,
                      package: Config.package,
                    ),
                  ],
                );
              }),
              if (!GetPlatform.isWeb) const SizedBox(),
              if (!GetPlatform.isWeb)
                Builder(builder: (context) {
                  bool enable = widget.value == 3;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        enable ? 'assets/icon/file.png' : 'assets/icon/file.png',
                        width: 24.w,
                        height: 24.w,
                        gaplessPlayback: false,
                        color: enable ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
                        package: Config.package,
                      ),
                    ],
                  );
                }),
              if (!GetPlatform.isWeb)
                Builder(builder: (context) {
                  bool enable = widget.value == 4;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        enable ? 'assets/icon/person.png' : 'assets/icon/person.png',
                        width: 24.w,
                        height: 24.w,
                        gaplessPlayback: false,
                        color: enable ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
                        package: Config.package,
                      ),
                    ],
                  );
                }),
            ],
          ),
          GestureWithScale(
            onTap: () {
              Navigator.of(context).push(CustomRoute(
                SendFilePage(
                  child: center,
                ),
              ));
              // todo 上线前别把这行代码放出来了
              // ConstIsland.onClipboardReceive('deviceName');
              // MethodChannel channel = MethodChannel('send_channel');
              // channel.invokeMethod('island');
            },
            child: center,
          ),
        ],
      ),
    );
  }
}

class BottomTab extends StatefulWidget {
  const BottomTab({Key? key, this.children, this.onChange}) : super(key: key);
  final List<Widget>? children;
  final void Function(int index)? onChange;

  @override
  State<BottomTab> createState() => _BottomTabState();
}

class _BottomTabState extends State<BottomTab> {
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height: 66.w,
        width: MediaQuery.of(context).size.width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.children!.length; i++)
              IconButton(
                padding: EdgeInsets.all(4.w),
                onPressed: () {
                  widget.onChange?.call(i);
                },
                icon: widget.children![i],
              ),
          ],
        ),
      ),
    );
  }
}
