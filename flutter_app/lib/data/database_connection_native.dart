/// 数据库连接 — Native 实现 (Android / Windows / macOS / Linux)
///
/// 使用 drift/native.dart 的 NativeDatabase
/// 数据库文件存储在应用文档目录

import 'dart:io' as io;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_stub.dart';

LazyDatabase createConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = io.File(p.join(dir.path, 'focus_fitness.db'));
    return NativeDatabase.createInBackground(file);
  });
}
