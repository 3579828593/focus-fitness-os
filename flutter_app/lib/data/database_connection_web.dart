/// 数据库连接 — Web 实现
///
/// 使用 drift/web.dart 的 WebDatabase (基于 sql.js WASM)
/// 数据存储在浏览器 IndexedDB 中

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

import 'database_stub.dart';

LazyDatabase createConnection() {
  return LazyDatabase(() async {
    return WebDatabase('focus_fitness_db');
  });
}
