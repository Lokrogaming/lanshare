import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:path/path.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/utils/ext_util.dart';
import 'package:speed_share/utils/path_util.dart';

import 'controller.dart';

class DownloadInfo {
  double progress = 0;
  String? speed = '0';
  int count = 0;
}

class DownloadController extends GetxController {
  /// key是url，value是进度
  Map<String?, DownloadInfo> progress = {};
  SettingController settingController = Get.find();

  final Dio dio = Dio();

  double getProgress(String? url) {
    if (progress.containsKey(url)) {
      return progress[url]!.progress;
    }
    return 0;
  }

  DownloadInfo? getInfo(String? url) {
    if (progress.containsKey(url)) {
      return progress[url];
    }
    return DownloadInfo();
  }

  // 计算网速
  Future<Timer> computeNetSpeed(DownloadInfo info) async {
    int tmpCount = 0;
    // todo 没释放
    Timer timer;
    timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      int diff = info.count - tmpCount;
      tmpCount = info.count;
      // Log.e('diff -> $diff');
      // 乘以2是因为半秒测的一次
      info.speed = FileSizeUtils.getFileSize(diff * 2);
      Log.e('网速 -> ${info.speed}');
    });
    return timer;
  }

  @override
  void onClose() {}
  Future<void> downloadFile(String url, String? dir) async {
    if (progress.containsKey(url) && progress[url]!.progress != 0.0) {
      showToast(S.current.fileIsDownloading);
      return;
    }
    if (progress.containsKey(url) && progress[url]!.progress == 1.0) {
      showToast(S.current.fileDownloadSuccess);
      return;
    }
    DownloadInfo info = DownloadInfo();
    progress[url] = info;
    String savePath = getSavePath(url, dir);
    Timer timer = await computeNetSpeed(info);
    // Response res = await RangeDownload.downloadWithChunks(
    //   '$urlPath?download=true', savePath,
    //   // isRangeDownload: false, //Support normal download
    //   maxChunk: 4,
    //   // dio: Dio(),//Optional parameters "dio".Convenient to customize request settings.
    //   // cancelToken: cancelToken,
    //   onReceiveProgress: (received, total) {
    //     count = received;
    //     fileDownratio = received / total;
    //     setState(() {});
    //     if (!isStarted) {
    //       startTime = DateTime.now();
    //       isStarted = true;
    //     }
    //   },
    // );
    try {
      await dio.download(
        '$url?download=true',
        savePath,
        onReceiveProgress: (count, total) {
          info.count = count;
          info.progress = count / total;
          update();
        },
      );
    } catch (e) {
      showToast(e.toString());
    }
    timer.cancel();
    update();
  }

  String getSavePath(String url, String? dir) {
    if (!settingController.enableFileClassify) {
      // 未开启文件分类
      String savePath = '$dir/${basename(url)}';
      return getSafePath(savePath);
    }
    // 开启文件分类
    String type = url.getType;
    String savePath = '$dir/$type/${basename(url)}';
    return getSafePath(savePath);
  }
}
