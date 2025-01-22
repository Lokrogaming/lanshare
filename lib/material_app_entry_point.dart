import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'app/controller/controller.dart';
import 'app/routes/app_pages.dart';
import 'dynamic_island.dart';
import 'generated/l10n.dart';
import 'themes/theme.dart';

class SpeedShare extends StatelessWidget {
  const SpeedShare({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String initRoute = SpeedPages.initial;
    SettingController settingController = Get.find();
    return ToastApp(
      child: LayoutBuilder(builder: (context, con) {
        return GetBuilder<SettingController>(
          builder: (context) {
            return GetMaterialApp(
              locale: settingController.currentLocale,
              title: '',
              initialRoute: initRoute,
              getPages: SpeedPages.routes,
              defaultTransition: GetPlatform.isAndroid ? Transition.fadeIn : null,
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.delegate.supportedLocales,
              builder: (context, child) {
                // ignore: deprecated_member_use
                final bool isDark = window.platformBrightness == Brightness.dark;
                final ThemeData theme = isDark ? dark() : light();
                return ResponsiveBreakpoints.builder(
                  child: Builder(
                    builder: (context) {
                      double adaptWidth = 0;
                      if (ResponsiveBreakpoints.of(context).isDesktop | ResponsiveBreakpoints.of(context).isTablet) {
                        adaptWidth = 896;
                      } else {
                        adaptWidth = 414;
                      }
                      return ScreenQuery(
                        uiWidth: adaptWidth,
                        screenWidth: con.maxWidth,
                        child: GetBuilder<SettingController>(
                          builder: (context) {
                            return Localizations(
                              locale: context.currentLocale!,
                              delegates: const [
                                S.delegate,
                                GlobalMaterialLocalizations.delegate,
                                GlobalWidgetsLocalizations.delegate,
                                GlobalCupertinoLocalizations.delegate,
                              ],
                              child: Theme(
                                data: theme,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    child!,
                                    if (settingController.enbaleConstIsland) const DynamicIsland(),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  breakpoints: const [
                    Breakpoint(start: 0, end: 500, name: MOBILE),
                    Breakpoint(start: 500, end: double.infinity, name: DESKTOP),
                  ],
                  breakpointsLandscape: [
                    const Breakpoint(start: 0, end: 500, name: MOBILE),
                    const Breakpoint(start: 500, end: double.infinity, name: DESKTOP),
                  ],
                );
              },
            );
          },
        );
      }),
    );
  }
}
