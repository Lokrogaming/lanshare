import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_manager/file_manager.dart' as file_manager;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart' hide Router;
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:global_repository/global_repository.dart';
import 'package:speed_share/app/controller/controller.dart';
import 'package:speed_share/config/config.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/global/global.dart';
import 'package:speed_share/model/model.dart';
import 'package:speed_share/modules/item/item.dart';
import 'package:speed_share/utils/utils.dart';
import 'utils/utils.dart';

int get type {
  if (GetPlatform.isWeb) {
    return web;
  } else if (GetPlatform.isAndroid) {
    return phone;
  } else if (GetPlatform.isDesktop) {
    return desktop;
  }
  return 3;
}

class ChatController extends GetxController with WidgetsBindingObserver {
  ChatController() {
    controller.addListener(() {
      // 这个监听主要是为了改变发送按钮为+号按钮
      if (controller.text.isNotEmpty) {
        hasInput = true;
      } else {
        hasInput = false;
      }
      update();
    });
    // 这里是shift+enter可以是实现换行的逻辑
    focusNode.onKey = (FocusNode node, event) {
      if (event.isShiftPressed) {
        inputMultiline = true;
        update();
      } else {
        inputMultiline = false;
        update();
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        return KeyEventResult.skipRemainingHandlers;
      }
      return KeyEventResult.ignored;
    };
  }
  // 一个标记位，是否输入多行
  bool inputMultiline = false;
  // 输入框用到的焦点
  FocusNode focusNode = FocusNode();
  List<Widget?> backup = [];
  // 输入框控制器
  TextEditingController controller = TextEditingController();
  // 列表渲染的widget列表
  List<Widget?> children = [];
  // 本机的ip地址列表
  List<String> addrs = [];
  // 列表的滑动控制器
  // scroll view controller
  ScrollController scrollController = ScrollController();

  Map<String?, int> dirItemMap = {};
  Map<String?, DirMessage> dirMsgMap = {};
  List<Map<String, dynamic>> cache = [];
  // 消息服务器成功绑定的端口
  int? messageBindPort;
  // 文件服务器成功绑定的端口
  int? shelfBindPort;
  int? fileServerPort;
  bool hasInput = false;
  // 发送文件需要等套接字初始化
  Completer initLock = Completer();
  DeviceController deviceController = Get.find();
  SettingController settingController = Get.find();
  Map<String, XFile> webFileSendCache = {};

  ValueNotifier<bool> connectState = ValueNotifier(false);

  // 创建聊天房间，调用时机为app启动时
  Future<void> createChatRoom() async {
    WidgetsBinding.instance.addObserver(this);
    // 启动消息服务器
    // start message server
    messageBindPort = await Server.start();
    // chatBindPort = await createChatServer();
    Log.i('消息服务器端口 : $messageBindPort');
    String udpData = '';
    udpData += await UniqueUtil.getDevicesId();
    udpData += ',$messageBindPort';
    // 将设备ID与聊天服务器成功创建的端口UDP广播出去
    Global().startSendBoardcast(udpData);
    // 保存本地的IP地址列表
    if (!GetPlatform.isWeb) {
      await refreshLocalAddress();
      update();
    }
    initChat();
  }

  /// 刷新本地ip地址列表
  Future<void> refreshLocalAddress() async {
    addrs = await PlatformUtil.localAddress();
  }

  Future<void> initChat() async {
    // 清除消息列表
    children.clear();
    connectState.value = true;
    // 监听消息
    // listenMessage();
    if (GetPlatform.isWeb) {
      // web 是靠轮询得到的消息
      initForWeb();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 100));
    await getSuccessBindPort();
    Log.i('shelf will server with $shelfBindPort port');
    if (!initLock.isCompleted) {
      initLock.complete();
    }
  }

  Future<void> initForWeb() async {
    String urlPrefix = url;
    if (!kReleaseMode) {
      urlPrefix = 'http://127.0.0.1:12000/';
    }
    Uri uri = Uri.parse(urlPrefix);
    int port = uri.port;
    deviceController.onDeviceConnect(
      shortHash(''),
      S.current.device,
      phone,
      'http://${uri.host}',
      port,
    );
    // Log.i('$urlPrefix/${info.messagePort}');

    sendJoinEvent('http://${uri.host}:$port');
    update();
    Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      // Log.i('web 轮训消息结果 ${res.data}');
      try {
        String webUrl = '${urlPrefix}message';
        Response res = await Dio().get(webUrl);
        Map<String, dynamic> data = jsonDecode(res.data);
        MessageBaseInfo info = MessageInfoFactory.fromJson(data)!;
        dispatch(info, children);
      } catch (e) {
        // Log.e('web 轮训消息error $e');
      }
    });
    if (!initLock.isCompleted) {
      initLock.complete();
    }
  }

  Future<void> getSuccessBindPort() async {
    if (!GetPlatform.isWeb) {
      shelfBindPort ??= await getSafePort(
        Config.shelfPortRangeStart,
        Config.shelfPortRangeEnd,
      );
      handleTokenCheck(shelfBindPort!);
    }
  }

  Future<void> sendDirFromPath(String dirPath) async {
    Directory dir = Directory(dirPath);
    String dirName = p.basename(dirPath);
    DirMessage dirMessage = DirMessage(
      dirName: dirName,
      fullSize: 0,
      deviceName: Global().deviceName,
      addrs: addrs,
      port: shelfBindPort,
    );
    // 发送消息
    sendMessage(dirMessage);
    // 将消息添加到本地列表
    children.add(MessageItemFactory.getMessageItem(
      dirMessage,
      true,
    ));
    scrollController.scrollToEnd();
    update();
    // TODO 这个功能难用
    // 传相同的文件，得到的文件大小是不一样的
    dir.list(recursive: true).listen((event) async {
      FileSystemEntity entity = event;
      String suffix = '';
      int size = 0;
      if (entity is Directory) {
        suffix = '/';
      } else if (entity is File) {
        size = await entity.length();
        ServerUtil.serveFile(entity.path, shelfBindPort!);
      }
      DirPartMessage dirPartMessage = DirPartMessage(
        path: event.path + suffix,
        size: size,
        partOf: dirName,
      );
      sendMessage(dirPartMessage);
      // Log.i(dirPartMessage);
    });
  }

  /// 发送文件夹
  /// send dir
  Future<void> sendDir() async {
    String? dirPath;
    if (GetPlatform.isDesktop) {
      dirPath = await getDirectoryPath(
        confirmButtonText: S.current.select,
      );
    } else {
      dirPath = await file_manager.FileManager.selectDirectory();
    }
    Log.d('dirPath -> $dirPath');
    if (dirPath == null) {
      return;
    }
    sendDirFromPath(dirPath);
  }

  // 通知web浏览器开始上传文件
  Future<void> notifyBroswerUploadFile(String? hash) async {
    List<String> addresses = await PlatformUtil.localAddress();
    final NotifyMessage notifyMessage = NotifyMessage(
      hash: hash,
      addrs: addresses,
      port: messageBindPort,
    );
    messageWebCache.add(notifyMessage.toJson());
  }

  // 给 web 和桌面端提供的方法
  Future<void> sendXFiles(List<XFile> files) async {
    await initLock.future;
    if (GetPlatform.isWeb) {
      for (XFile xFile in files) {
        Log.w('-' * 10);
        Log.w('xFile.path -> ${xFile.path}');
        Log.w('xFile.name -> ${xFile.name}');
        Log.w('xFile.length -> ${await xFile.length()}');
        Log.w('-' * 10);
        String hash = shortHash(xFile);
        webFileSendCache[hash] = xFile;
        final BroswerFileMessage sendFileInfo = BroswerFileMessage(
          // 用来客户端显示
          fileName: xFile.name,
          hash: hash,
          fileSize: FileSizeUtils.getFileSize(await xFile.length()),
          deviceName: Global().deviceName,
          blob: xFile.path,
        );
        // 发送消息
        // socket.send(sendFileInfo.toString());
        sendMessage(sendFileInfo);
        // 将消息添加到本地列表
        children.add(MessageItemFactory.getMessageItem(
          sendFileInfo,
          true,
        ));
        scrollController.scrollToEnd();
        update();
      }
    } else {
      for (XFile xFile in files) {
        Log.d('-' * 10);
        Log.d('xFile.path -> ${xFile.path}');
        Log.d('xFile.name -> ${xFile.name}');
        Log.d('xFile.length -> ${await xFile.length()}');
        Log.d('-' * 10);
        sendFileFromPath(xFile.path);
      }
    }
  }

  // 选择文件后并没有第一时间发送，只是发送了一条普通消息
  Future<void> sendFileForBroswerAndDesktop() async {
    List<XFile>? files = await getFilesForDesktopAndWeb();
    if (files == null) {
      return;
    }
    sendXFiles(files);
  }

  // web 端速享上传文件调用的方法
  Future<void> uploadFileForWeb(XFile xFile, String urlPrefix) async {
    try {
      String base64Name = base64Encode(utf8.encode(xFile.name));
      Log.w(base64Name);
      Response response2 = await Dio().post(
        '$urlPrefix/file_upload',
        data: xFile.openRead(),
        onSendProgress: (count, total) {
          Log.v('count:$count total:$total pro:${count / total}');
        },
        options: Options(
          headers: {
            Headers.contentLengthHeader: await xFile.length(),
            HttpHeaders.contentTypeHeader: ContentType.binary.toString(),
            'filename': base64Name,
            'blob': xFile.path,
          },
        ),
      );
      Log.w(response2);
    } catch (e) {
      Log.e('Web 上传文件出错 : $e');
    }
  }

  /// useSystemPicker: 是否使用系统文件选择器
  Future<void> sendFileForAndroid({
    bool useSystemPicker = false,
    BuildContext? context,
  }) async {
    // 选择文件路径
    List<String?> filePaths = await getFilesPathsForAndroid(useSystemPicker);
    Log.i('filePaths -> $filePaths');
    if (filePaths.isEmpty) {
      return;
    }
    for (String? filePath in filePaths) {
      Log.v(filePath);
      if (filePath == null) {
        return;
      }
      sendFileFromPath(filePath);
    }
  }

  // 基于一个文件路径发送消息
  // send a file message base file path
  Future<void> sendFileFromPath(String filePath) async {
    await getSuccessBindPort();
    ServerUtil.serveFile(filePath, shelfBindPort!);
    // 替换windows的路径分隔符
    filePath = filePath.replaceAll('\\', '/');
    // 读取文件大小
    int size = await File(filePath).length();
    // 替换windows盘符
    filePath = filePath.replaceAll(RegExp('^[A-Z]:'), '');
    p.Context context;
    if (GetPlatform.isWindows) {
      context = p.windows;
    } else {
      context = p.posix;
    }
    final FileMessage sendFileInfo = FileMessage(
      filePath: filePath,
      fileName: context.basename(filePath),
      fileSize: FileSizeUtils.getFileSize(size),
      addrs: addrs,
      port: shelfBindPort,
      sendFrom: Global().deviceName,
    );
    // 发送消息
    sendMessage(sendFileInfo);
    // 将消息添加到本地列表
    children.add(MessageItemFactory.getMessageItem(
      sendFileInfo,
      true,
    ));
    scrollController.scrollToEnd();
    update();
  }

  void handleMessage(Map<String, dynamic> data) {
    Log.e('handleMessage :$data');
    MessageBaseInfo info = MessageInfoFactory.fromJson(data)!;
    dispatch(info, children);
  }

  Future<void> dispatch(MessageBaseInfo info, List<Widget?> children) async {
    if (info.deviceId == Global().uniqueKey) {
      return;
    }
    switch (info.runtimeType) {
      // 剪切板消息
      case ClipboardMessage:
        if (!settingController.clipboardShare) {
          return;
        }
        ClipboardMessage clipboardMessage = info as ClipboardMessage;
        Clipboard.setData(ClipboardData(text: clipboardMessage.content ?? ''));
        // 置为false是为了不让此次复制行为再同步出去
        Global().canShareClip = false;
        Future.delayed(const Duration(milliseconds: 300), () {
          Global().canShareClip = true;
        });
        if (settingController.enbaleConstIsland) {
          ConstIsland.onClipboardReceive(clipboardMessage.deviceName);
        } else {
          showToast('${clipboardMessage.deviceName}的剪切板已复制');
        }
        break;
      // 设备加入消息
      case JoinMessage:
        JoinMessage joinMessage = info as JoinMessage;
        // 当连接设备不是本机的时候
        if (info.deviceId != Global().uniqueKey) {
          Log.i('JoinMessage -> $joinMessage');
          Log.i('Global().uniqueKey -> ${Global().uniqueKey}');
          // 这个不带端口，主要是为了筛选IP
          String? urlPrefix = await getCorrectUrlWithAddressAndPort(
            joinMessage.addrs!,
            joinMessage.filePort,
          );
          Log.i('计算结果:$urlPrefix');
          if (urlPrefix == null) {
            return;
          }
          // 先回连接消息
          sendJoinEvent('$urlPrefix:${joinMessage.messagePort}');
          try {
            // 会先尝试去找是否已经被记录了
            // will try to find object first
            deviceController.connectDevice.firstWhere((element) => element.id == info.deviceId);
          } catch (e) {
            // catch住说明没有找到
            deviceController.onDeviceConnect(
              info.deviceId,
              info.deviceName,
              info.deviceType,
              urlPrefix,
              joinMessage.messagePort,
            );
            Log.i('$urlPrefix/${joinMessage.messagePort}');
            // 同步之前发送过的消息
            for (Map<String, dynamic> data in messageCache) {
              try {
                // ignore: unused_local_variable
                Response res = await httpInstance!.post(
                  '$urlPrefix:${joinMessage.messagePort}',
                  data: data,
                );
              } catch (e) {
                Log.e('cache send error : $e');
              }
            }
          }
          return;
        }
        break;
      case FileMessage:
        FileMessage fileMessage = info as FileMessage;
        // 文件消息，需要先计算出正确的下载地址
        String? url = await getCorrectUrlWithAddressAndPort(
          fileMessage.addrs!,
          fileMessage.port,
        );
        fileMessage.url = '$url:${fileMessage.port}';
        // 这里有种情况，A,B,C三台机器，A创建房间，B加入发送一个文件后退出了速享
        // C加入A的房间，自然是不能再拿到这个文件的信息了
        fileMessage.url ??= '';
        onNewFileReceive?.call(FileDynamicIsland(
          info: info,
          sendByUser: false,
        ));
        if (settingController.enbaleConstIsland) {
          ConstIsland.onFileReceive(fileMessage.toJson());
        }
        break;
      case DirMessage:
        DirMessage dirMessage = info as DirMessage;
        // 保存文件夹消息所在的index
        dirItemMap[dirMessage.dirName] = children.length;
        dirMsgMap[dirMessage.dirName] = info;
        String? url = await getCorrectUrlWithAddressAndPort(dirMessage.addrs!, dirMessage.port);
        dirMessage.urlPrifix = '$url:${dirMessage.port}';
        Log.w('dirItemMap -> $dirItemMap');
        break;
      case DirPartMessage:
        DirPartMessage dirPartMessage = info as DirPartMessage;
        if (dirPartMessage.stat == 'complete') {
          Log.i('完成发送');
          dirMsgMap[dirPartMessage.partOf]!.canDownload = true;
          children[dirItemMap[dirPartMessage.partOf]!] = MessageItemFactory.getMessageItem(
            dirMsgMap[dirPartMessage.partOf],
            false,
          );
          update();
        } else {
          // 下面这行是不断重置文件夹的大小
          dirMsgMap[dirPartMessage.partOf]!.fullSize = dirMsgMap[dirPartMessage.partOf]!.fullSize! + (dirPartMessage.size ?? 0);
          dirMsgMap[dirPartMessage.partOf]!.paths!.add(dirPartMessage.path);
          children[dirItemMap[dirPartMessage.partOf]!] = MessageItemFactory.getMessageItem(
            dirMsgMap[dirPartMessage.partOf],
            false,
          );
          update();
        }
        return;
      case NotifyMessage:
        NotifyMessage notifyMessage = info as NotifyMessage;
        if (GetPlatform.isWeb) {
          if (webFileSendCache.containsKey(notifyMessage.hash)) {
            Log.e(info);
            String? url = await getCorrectUrlWithAddressAndPort(
              notifyMessage.addrs!,
              notifyMessage.port,
            );
            Log.d('uploadFileForWeb url -> $url:${notifyMessage.port}');
            if (url != null) {
              uploadFileForWeb(webFileSendCache[notifyMessage.hash]!, '$url:${notifyMessage.port}');
            } else {
              showToast(S.current.noIPFound);
            }
          }
        }
        return;
      default:
    }
    // 往聊天列表中添加一条消息
    Widget? item = MessageItemFactory.getMessageItem(
      info,
      false,
    );
    Log.w(info);
    if (item != null) {
      children.add(item);
      // 自动滑动，振动，更新UI
      scrollController.scrollToEnd();
      vibrate();
      update();
    }
  }

  /// 给灵动岛用的
  void Function(Widget fileWidget)? onNewFileReceive;
  // 储存已经发送过的消息
  // 在第一次连接到设备的时候，会将消息同步过去
  List<Map<String, dynamic>> messageCache = [];
  // 给Web端用的
  List<Map<String, dynamic>> messageWebCache = [];
  void sendMessage(MessageBaseInfo info) {
    info.deviceType = type;
    info.deviceId = Global().uniqueKey;
    messageCache.add(info.toJson());
    messageWebCache.add(info.toJson());
    deviceController.send(info.toJson());
  }

  /// 发送文本消息
  void sendTextMsg() {
    TextMessage info = TextMessage(
      content: controller.text,
      sendFrom: Global().deviceName,
    );
    sendMessage(info);
    children.add(MessageItemFactory.getMessageItem(
      info,
      true,
    ));
    update();
    controller.clear();
    scrollController.scrollToEnd();
  }

  // 当切换到所有设备时调用的函数
  void restoreList() {
    backup.clear();
    update();
  }

  void changeListToDevice(Device device) {
    backup.clear();
    for (Map map in cache) {
      MessageBaseInfo? info = MessageInfoFactory.fromJson(map as Map<String, dynamic>);
      if (info is JoinMessage) {
        continue;
      }
      if (info!.deviceType == device.deviceType) {
        dispatch(info, backup);
      }
    }
  }

  @override
  void onClose() {
    Log.e('chat controller dispose');
    focusNode.dispose();
    controller.dispose();
    scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // 刷新本地ip列表
        refreshLocalAddress();
        break;
      default:
    }
    // Log.v('didChangeAppLifecycleState : $state');
  }
}
