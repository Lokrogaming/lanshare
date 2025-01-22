import 'package:file_selector/file_selector.dart';
import 'package:get/get.dart';
import 'package:file_manager/file_manager.dart' as file_manager;

// 用来选择文件的
Future<List<XFile>?> getFilesForDesktopAndWeb() async {
  final typeGroup = XTypeGroup(
    label: 'images',
    extensions: GetPlatform.isWeb ? [''] : null,
  );
  final files = await openFiles(acceptedTypeGroups: [typeGroup]);
  if (files.isEmpty) {
    return null;
  }
  return files;
}

/// 选择文件路径
Future<List<String?>> getFilesPathsForAndroid(bool useSystemPicker) async {
  List<String> filePaths = [];
  if (!useSystemPicker) {
    filePaths = (await file_manager.FileManager.selectFile());
  } else {
    final List<XFile> files = await openFiles();
    return files.map((e) => e.path).toList();
  }
  return filePaths;
}
