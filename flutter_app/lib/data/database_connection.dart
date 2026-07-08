/// 数据库连接 — 条件导入入口
///
/// 自动根据平台选择:
///   dart:io  → database_connection_native.dart (NativeDatabase)
///   dart:html → database_connection_web.dart (WebDatabase)
///
/// 使用方式 (在 database.dart 中):
///   import 'database_connection.dart';

export 'database_stub.dart'
    if (dart.library.io) 'database_connection_native.dart'
    if (dart.library.html) 'database_connection_web.dart';
