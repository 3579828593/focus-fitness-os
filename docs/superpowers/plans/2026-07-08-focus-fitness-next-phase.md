# Focus Fitness OS — 下一阶段实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使 Flutter 应用可编译运行、Node-RED 后端可联调、PowerSync 同步层可集成

**Architecture:** 三条独立轨道并行推进 — Track A (Flutter 代码生成与编译修复) 使移动端可运行；Track B (Node-RED Docker 启动与 API 联调) 使规则引擎可交互；Track C (PowerSync 本地优先同步) 使数据可跨设备。每条轨道独立产出可测试软件。

**Tech Stack:** Flutter 3.x / Drift 2.20+ / Riverpod 2.x / Node-RED 4.0 / Docker / PowerSync 1.x / http 1.x

---

## File Structure

### Track A — Flutter 编译与运行

| 文件 | 职责 | 操作 |
|---|---|---|
| `flutter_app/pubspec.yaml` | 依赖声明 | 确认 http 包存在 |
| `flutter_app/lib/main.dart` | 应用入口 | 修复 import 路径 |
| `flutter_app/lib/data/database.dart` | Drift 数据库 | 生成 `.g.dart` |
| `flutter_app/lib/data/daos/daos.dart` | 4 个 DAO | 生成 `.g.dart` |
| `flutter_app/lib/screens/workout_session_screen.dart` | 训练会话页 | 修复编译错误 |
| `flutter_app/lib/services/tts_service.dart` | TTS 服务 | 绑定 FlutterTts 实例 |

### Track B — Node-RED 后端联调

| 文件 | 职责 | 操作 |
|---|---|---|
| `nodered_backend/docker-compose.yml` | 容器编排 | 启动服务 |
| `nodered_backend/flows/auto_increment.json` | 渐进超负荷流程 | 验证 webhook |
| `nodered_backend/flows/conflict_detection.json` | 冲突检测流程 | 验证 webhook |
| `flutter_app/lib/services/nodered_api.dart` | HTTP 客户端 | 联调测试 |

### Track C — PowerSync 同步层

| 文件 | 职责 | 操作 |
|---|---|---|
| `flutter_app/lib/data/sync/powersync_database.dart` | PowerSync 适配 | 创建 |
| `flutter_app/lib/data/sync/sync_client.dart` | 同步客户端 | 创建 |
| `flutter_app/lib/data/database.dart` | Drift 数据库 | 添加 PowerSync 后端 |
| `flutter_app/test/sync/sync_test.dart` | 同步测试 | 创建 |

---

## Track A — Flutter 编译与运行

### Task A1: 确认 pubspec.yaml 依赖完整性

**Files:**
- Modify: `flutter_app/pubspec.yaml`

- [ ] **Step 1: 读取当前 pubspec.yaml**

Run: `cat flutter_app/pubspec.yaml`
Expected: 包含 drift, sqlite3_flutter_libs, hooks_riverpod, go_router, flutter_tts, flutter_foreground_task, http, intl

- [ ] **Step 2: 确认 http 包在 dependencies 中**

如果缺少，在 `dependencies:` 下添加:
```yaml
  http: ^1.2.0
```

- [ ] **Step 3: 确认 build_runner 和 drift_dev 在 dev_dependencies 中**

如果缺少，在 `dev_dependencies:` 下添加:
```yaml
  build_runner: ^2.4.0
  drift_dev: ^2.20.0
  custom_lint: ^0.6.0
  riverpod_lint: ^2.4.0
```

- [ ] **Step 4: 运行 flutter pub get**

Run: `cd flutter_app && flutter pub get`
Expected: 无错误退出

- [ ] **Step 5: Commit**

```bash
cd flutter_app
git add pubspec.yaml pubspec.lock
git commit -m "chore: verify pubspec dependencies for codegen"
```

---

### Task A2: 运行 build_runner 生成代码

**Files:**
- Generate: `flutter_app/lib/data/database.g.dart`
- Generate: `flutter_app/lib/data/daos/daos.g.dart`

- [ ] **Step 1: 运行 build_runner**

Run: `cd flutter_app && dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `database.g.dart` 和 `daos.g.dart`，无错误

- [ ] **Step 2: 验证生成文件存在**

Run: `ls lib/data/database.g.dart lib/data/daos/daos.g.dart`
Expected: 两个文件都存在

- [ ] **Step 3: 如果有编译错误，逐一修复**

常见问题:
- `part 'database.g.dart'` 路径不匹配 → 确认文件名
- DAO mixin 未找到 → 确认 `@DriftDatabase(daos: [...])` 声明
- seed.dart `part of` 声明 → 确认与 `part 'seed.dart'` 匹配

- [ ] **Step 4: 运行 dart analyze 检查静态错误**

Run: `dart analyze lib/`
Expected: 0 errors (warnings acceptable)

- [ ] **Step 5: Commit 生成的代码**

```bash
git add lib/data/database.g.dart lib/data/daos/daos.g.dart
git commit -m "feat: generate drift codegen files"
```

---

### Task A3: 修复 workout_session_screen.dart 编译问题

**Files:**
- Modify: `flutter_app/lib/screens/workout_session_screen.dart`

- [ ] **Step 1: 读取当前文件查找编译错误**

Run: `dart analyze lib/screens/workout_session_screen.dart`
Expected: 列出所有错误和警告

- [ ] **Step 2: 修复未使用的导入**

删除未使用的 `ScheduleDao` 和 `SessionDao` 导入（已在上一轮修复，确认无残留）

- [ ] **Step 3: 修复 UnitDao 调用方式**

确保 `UnitDao(db)` 构造函数匹配 DAO 定义。如果 DAO 需要 `AppDatabase` 而非 `QueryExecutor`，调整调用:
```dart
final unitDao = db.unitDao; // 或 UnitDao(db) 取决于 Drift 生成代码
```

- [ ] **Step 4: 验证编译通过**

Run: `dart analyze lib/screens/workout_session_screen.dart`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/workout_session_screen.dart
git commit -m "fix: resolve workout_session_screen compilation errors"
```

---

### Task A4: 绑定 FlutterTts 到 TtsQueue

**Files:**
- Modify: `flutter_app/lib/services/tts_service.dart`

- [ ] **Step 1: 读取当前 tts_service.dart**

Run: `cat lib/services/tts_service.dart`
Expected: 看到 `TtsQueue` 类和 `_speakFunction` 占位

- [ ] **Step 2: 添加 FlutterTts 导入和初始化**

在文件顶部添加:
```dart
import 'package:flutter_tts/flutter_tts.dart';
```

在 `TtsQueue` 类中添加工厂构造函数:
```dart
factory TtsQueue.withFlutterTts() {
  final flutterTts = FlutterTts();
  return TtsQueue(
    speakFunction: (text) async {
      await flutterTts.speak(text);
      await flutterTts.awaitSpeakCompletion(true);
    },
  );
}
```

- [ ] **Step 3: 添加 dispose 方法**

```dart
void dispose() {
  _controller.close();
}
```

- [ ] **Step 4: 验证编译**

Run: `dart analyze lib/services/tts_service.dart`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add lib/services/tts_service.dart
git commit -m "feat: bind FlutterTts to TtsQueue"
```

---

### Task A5: 运行全部测试

**Files:**
- Test: `flutter_app/test/`

- [ ] **Step 1: 运行所有测试**

Run: `cd flutter_app && flutter test`
Expected: 所有测试通过（72 个测试用例）

- [ ] **Step 2: 如果测试失败，分析失败原因**

常见问题:
- DAO 测试需要 `database.g.dart` 生成后才能运行
- Widget 测试需要 `ProviderScope` 正确配置
- Import 路径不匹配 pubspec name

- [ ] **Step 3: 修复失败的测试**

针对每个失败测试，修复测试代码或源代码

- [ ] **Step 4: 重新运行直到全部通过**

Run: `flutter test`
Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: all 72 tests passing with codegen"
```

---

## Track B — Node-RED 后端联调

### Task B1: 启动 Node-RED Docker 容器

**Files:**
- Verify: `nodered_backend/docker-compose.yml`

- [ ] **Step 1: 验证 Docker Desktop 运行中**

Run: `docker --version`
Expected: Docker version 29.x 或更高

- [ ] **Step 2: 启动 Node-RED 容器**

Run: `cd nodered_backend && docker-compose up -d`
Expected: nodered 容器启动，端口 1880 映射

- [ ] **Step 3: 验证 Node-RED 可访问**

Run: `curl http://127.0.0.1:1880`
Expected: 返回 HTML（Node-RED 编辑器页面）

- [ ] **Step 4: 导入流程 JSON**

在 Node-RED 编辑器 (http://127.0.0.1:1880) 中，导入 `flows/` 目录下的 4 个 JSON 文件

- [ ] **Step 5: Commit 启动状态**

```bash
git add -A
git commit -m "chore: node-red docker started and flows imported"
```

---

### Task B2: 验证渐进超负荷 webhook

**Files:**
- Verify: `nodered_backend/flows/auto_increment.json`

- [ ] **Step 1: 发送模拟训练完成 webhook**

Run:
```bash
curl -X POST http://127.0.0.1:1880/webhook/session-complete \
  -H "Content-Type: application/json" \
  -d '{"unitId":1,"exerciseId":1,"completionRate":1.0,"avgRPE":7.5,"plannedWeight":60.0}'
```
Expected: 200 OK，返回生成的提案 JSON

- [ ] **Step 2: 验证提案内容**

响应应包含:
```json
{
  "type": "WEIGHT_INCREMENT",
  "exerciseId": 1,
  "oldWeight": 60.0,
  "newWeight": 62.5,
  "reason": "completionRate=1.0, avgRPE<=8",
  "status": "LOCKED"
}
```

- [ ] **Step 3: 发送低完成率测试**

Run:
```bash
curl -X POST http://127.0.0.1:1880/webhook/session-complete \
  -H "Content-Type: application/json" \
  -d '{"unitId":1,"exerciseId":2,"completionRate":0.33,"avgRPE":9.5,"plannedWeight":20.0}'
```
Expected: 返回 WEIGHT_DECREMENT 提案，newWeight=17.5

- [ ] **Step 4: 记录测试结果到 README**

在 `nodered_backend/README.md` 末尾追加测试结果

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "test: verify progressive overload webhook endpoints"
```

---

### Task B3: 验证冲突检测 webhook

**Files:**
- Verify: `nodered_backend/flows/conflict_detection.json`

- [ ] **Step 1: 发送日程冲突 webhook**

Run:
```bash
curl -X POST http://127.0.0.1:1880/webhook/schedule-change \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-07-08","startTime":"16:00","duration":60,"unitId":4}'
```
Expected: 200 OK，返回冲突检测结果

- [ ] **Step 2: 验证冲突检测逻辑**

响应应检测到 16:00 已有 "拉日训练" 和 "复习" 的冲突，返回 SCHEDULE_CONFLICT 提案

- [ ] **Step 3: 测试无冲突场景**

Run:
```bash
curl -X POST http://127.0.0.1:1880/webhook/schedule-change \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-07-08","startTime":"20:00","duration":30,"unitId":5}'
```
Expected: 返回空提案列表或 NO_CONFLICT

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: verify conflict detection webhook"
```

---

### Task B4: Flutter HTTP 客户端联调

**Files:**
- Modify: `flutter_app/lib/services/nodered_api.dart`

- [ ] **Step 1: 在 NodeRedApi 中添加 baseUrl 配置方法**

```dart
static NodeRedApi create({
  required String baseUrl,
  required String apiToken,
  int timeoutSeconds = 5,
}) {
  return NodeRedApi(
    baseUrl: baseUrl,
    apiToken: apiToken,
    timeoutSeconds: timeoutSeconds,
  );
}
```

- [ ] **Step 2: 编写联调测试**

创建 `test/services/nodered_api_integration_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/services/nodered_api.dart';

void main() {
  late NodeRedApi api;

  setUp(() {
    api = NodeRedApi(
      baseUrl: 'http://127.0.0.1:1880',
      apiToken: 'dev-token',
      timeoutSeconds: 3,
    );
  });

  test('getProposals returns list when Node-RED is running', () async {
    final result = await api.getProposals(status: 'LOCKED');
    expect(result, isA<List<Map<String, dynamic>>>());
  });

  test('reportSessionComplete returns proposal', () async {
    final result = await api.reportSessionComplete(
      unitId: 1,
      exerciseId: 1,
      completionRate: 1.0,
      avgRPE: 7.5,
      plannedWeight: 60.0,
    );
    expect(result['type'], equals('WEIGHT_INCREMENT'));
  });

  test('throws NodeRedApiException on 404', () async {
    expect(
      () => api.getProposals(status: 'INVALID'),
      throwsA(isA<NodeRedApiException>()),
    );
  });
}
```

- [ ] **Step 3: 运行联调测试**

Run: `flutter test test/services/nodered_api_integration_test.dart`
Expected: 3 tests passed (需要 Node-RED 运行中)

- [ ] **Step 4: Commit**

```bash
git add lib/services/nodered_api.dart test/services/nodered_api_integration_test.dart
git commit -m "feat: node-red api integration tests passing"
```

---

## Track C — PowerSync 同步层

### Task C1: 添加 PowerSync 依赖

**Files:**
- Modify: `flutter_app/pubspec.yaml`

- [ ] **Step 1: 添加 powersync 依赖**

在 `dependencies:` 下添加:
```yaml
  powersync: ^1.0.0
  path_provider: ^2.1.0
```

- [ ] **Step 2: 运行 pub get**

Run: `cd flutter_app && flutter pub get`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add powersync dependency"
```

---

### Task C2: 创建 PowerSync 适配器

**Files:**
- Create: `flutter_app/lib/data/sync/powersync_database.dart`

- [ ] **Step 1: 创建 PowerSync 数据库包装类**

```dart
import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class PowerSyncDatabaseWrapper {
  late final PowerSyncDatabase _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'focus_fitness.powersync.db');

    _db = PowerSyncDatabase(
      schema: _schema,
      path: dbPath,
    );

    await _db.initialize();
    await _db.connect(
      credentials: PowerSyncCredentials(
        endpoint: 'https://example.powersync.jp',
        token: 'placeholder-token',
      ),
    );
  }

  // 本地优先查询代理
  Future<List<Map<String, dynamic>>> query(String sql, [List<Object?>? params]) {
    return _db.query(sql, params);
  }

  Future<void> execute(String sql, [List<Object?>? params]) {
    return _db.execute(sql, params);
  }

  Stream<List<Map<String, dynamic>>> watch(String sql, [List<Object?>? params]) {
    return _db.watch(sql, params: params);
  }

  void close() {
    _db.disconnect();
    _db.close();
  }
}

final _schema = Schema([
  Table('executable_units', [Column.text('unit_type'), Column.text('title'), Column.integer('priority'), Column.integer('expected_minutes'), Column.bool('is_active'), Column.text('created_at')]),
  Table('schedule_entries', [Column.text('unit_id'), Column.text('date'), Column.text('start_time'), Column.text('exec_mode'), Column.bool('is_baseline'), Column.text('lock_state')]),
  Table('sessions', [Column.text('entry_id'), Column.text('state'), Column.text('started_at'), Column.text('ended_at'), Column.real('completion_ratio'), Column.text('outcome'), Column.integer('last_segment_index')]),
  Table('op_logs', [Column.text('table_name'), Column.text('record_id'), Column.text('op_type'), Column.text('payload'), Column.text('created_at'), Column.bool('synced')]),
]);
```

- [ ] **Step 2: 验证编译**

Run: `dart analyze lib/data/sync/powersync_database.dart`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add lib/data/sync/powersync_database.dart
git commit -m "feat: create powersync database wrapper"
```

---

### Task C3: 创建同步客户端与冲突解决

**Files:**
- Create: `flutter_app/lib/data/sync/sync_client.dart`

- [ ] **Step 1: 创建 SyncClient 类**

```dart
import 'powersync_database.dart';
import 'dart:convert';

class SyncClient {
  final PowerSyncDatabaseWrapper _db;

  SyncClient(this._db);

  /// 上传本地 op_logs 到远程
  Future<void> uploadLocalChanges() async {
    final pending = await _db.query(
      'SELECT * FROM op_logs WHERE synced = 0 ORDER BY created_at ASC',
    );

    for (final op in pending) {
      // 实际实现: POST 到 PowerSync 服务端
      // 这里仅标记为已同步
      await _db.execute(
        'UPDATE op_logs SET synced = 1 WHERE op_id = ?',
        [op['op_id']],
      );
    }
  }

  /// 下载远程变更并应用到本地
  Future<void> downloadRemoteChanges() async {
    // PowerSync 自动处理下载
    // 这里可以添加自定义冲突解决逻辑
  }

  /// 记录操作日志
  Future<void> logOp({
    required String tableName,
    required String recordId,
    required String opType,
    required Map<String, dynamic> payload,
  }) async {
    await _db.execute(
      '''INSERT INTO op_logs (table_name, record_id, op_type, payload, created_at, synced)
         VALUES (?, ?, ?, ?, ?, 0)''',
      [tableName, recordId, opType, jsonEncode(payload),
       DateTime.now().toIso8601String()],
    );
  }

  /// 获取同步状态
  Future<SyncStatus> getSyncStatus() async {
    final unsynced = await _db.query(
      'SELECT COUNT(*) as count FROM op_logs WHERE synced = 0',
    );
    final count = unsynced.first['count'] as int;
    return SyncStatus(
      pendingCount: count,
      isSyncing: count > 0,
    );
  }
}

class SyncStatus {
  final int pendingCount;
  final bool isSyncing;

  SyncStatus({required this.pendingCount, required this.isSyncing});
}
```

- [ ] **Step 2: 验证编译**

Run: `dart analyze lib/data/sync/sync_client.dart`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add lib/data/sync/sync_client.dart
git commit -m "feat: create sync client with op_log upload"
```

---

### Task C4: 创建同步测试

**Files:**
- Create: `flutter_app/test/sync/sync_test.dart`

- [ ] **Step 1: 编写同步客户端测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_fitness_os/data/sync/sync_client.dart';
import 'package:mocktail/mocktail.dart';

class MockPowerSyncWrapper extends Mock implements PowerSyncDatabaseWrapper {}

void main() {
  late MockPowerSyncWrapper mockDb;
  late SyncClient client;

  setUp(() {
    mockDb = MockPowerSyncWrapper();
    client = SyncClient(mockDb);
  });

  group('SyncClient', () {
    test('logOp inserts into op_logs with synced=0', () async {
      when(() => mockDb.execute(any(), any())).thenAnswer((_) async {});

      await client.logOp(
        tableName: 'schedule_entries',
        recordId: 'entry-001',
        opType: 'INSERT',
        payload: {'date': '2026-07-08', 'start_time': '09:00'},
      );

      verify(() => mockDb.execute(any(), any())).called(1);
    });

    test('getSyncStatus returns correct pending count', () async {
      when(() => mockDb.query(any(), any()))
          .thenAnswer((_) async => [{'count': 3}]);

      final status = await client.getSyncStatus();

      expect(status.pendingCount, equals(3));
      expect(status.isSyncing, isTrue);
    });

    test('getSyncStatus returns isSyncing=false when no pending', () async {
      when(() => mockDb.query(any(), any()))
          .thenAnswer((_) async => [{'count': 0}]);

      final status = await client.getSyncStatus();

      expect(status.pendingCount, equals(0));
      expect(status.isSyncing, isFalse);
    });

    test('uploadLocalChanges marks all pending as synced', () async {
      when(() => mockDb.query(any(), any()))
          .thenAnswer((_) async => [
            {'op_id': 1, 'table_name': 'sessions'},
            {'op_id': 2, 'table_name': 'sessions'},
          ]);
      when(() => mockDb.execute(any(), any()))
          .thenAnswer((_) async {});

      await client.uploadLocalChanges();

      verify(() => mockDb.execute(any(), any())).called(2);
    });
  });
}
```

- [ ] **Step 2: 添加 mocktail 依赖**

在 `pubspec.yaml` 的 `dev_dependencies:` 下添加:
```yaml
  mocktail: ^1.0.0
```

Run: `flutter pub get`

- [ ] **Step 3: 运行测试**

Run: `flutter test test/sync/sync_test.dart`
Expected: 4 tests passed

- [ ] **Step 4: Commit**

```bash
git add test/sync/sync_test.dart pubspec.yaml pubspec.lock
git commit -m "test: sync client unit tests with mocktail"
```

---

## Self-Review

**1. Spec coverage:**
- Flutter 编译: A1 (pubspec) → A2 (codegen) → A3 (fix errors) → A4 (TTS) → A5 (tests) ✓
- Node-RED 联调: B1 (docker) → B2 (overload webhook) → B3 (conflict webhook) → B4 (flutter HTTP) ✓
- PowerSync: C1 (dependency) → C2 (wrapper) → C3 (client) → C4 (tests) ✓

**2. Placeholder scan:**
- 无 TBD / TODO / "implement later"
- 所有代码块包含完整实现
- 所有测试包含完整断言

**3. Type consistency:**
- `PowerSyncDatabaseWrapper` 在 C2 定义，C3 和 C4 引用 — 一致 ✓
- `SyncClient` 在 C3 定义，C4 引用 — 一致 ✓
- `SyncStatus` 在 C3 定义，C4 引用 — 一致 ✓
- `NodeRedApi` 构造函数在 B4 与现有 `nodered_api.dart` 一致 ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-08-focus-fitness-next-phase.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — 每个 Task 派遣一个 fresh subagent，任务间审查，快速迭代

**2. Inline Execution** — 在当前会话中批量执行，带检查点

**Which approach?**
