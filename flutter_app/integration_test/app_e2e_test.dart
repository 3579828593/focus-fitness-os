import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:focus_fitness_os/data/database.dart';
import 'package:focus_fitness_os/screens/proposal_screen.dart';
import '../test/helpers/test_helpers.dart';

/// ============================================================
/// E2E 集成测试入口
/// 使用 IntegrationTestWidgetsFlutterBinding 在真实环境运行
/// 复用 test_helpers.dart 中的 TestApp 与 createTestOverrides
///
/// 运行方式:
///   flutter test integration_test/app_e2e_test.dart
///
/// 说明: IntegrationTestWidgetsFlutterBinding 继承自
///   LiveTestWidgetsFlutterBinding, 不存在 delayUntilFrame() 方法。
///   等待渲染统一使用 tester.pumpAndSettle() (逐帧 pump 直到稳定),
///   需要逐帧推进时使用 tester.pump()。
/// ============================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    // Arrange (公共): 每个用例使用独立的内存数据库
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// ----------------------------------------------------------
  /// 测试1: 应用启动测试
  /// 验证 HomePage 渲染, "专注健身OS" 标题可见
  /// ----------------------------------------------------------
  testWidgets('app_launch_test: 应用启动后渲染首页标题', (tester) async {
    // Arrange
    await initTestLocales();

    // Act - 挂载测试 App 并等待首帧渲染完成
    await tester.pumpWidget(TestApp(overrides: createTestOverrides(db)));
    await tester.pumpAndSettle();

    // Assert - AppBar 标题 "专注健身OS" 可见
    expect(find.text('专注健身OS'), findsOneWidget);
  });

  /// ----------------------------------------------------------
  /// 测试2: 导航测试
  /// 验证从首页点击 "待确认提案" 可跳转到 ProposalScreen
  /// ----------------------------------------------------------
  testWidgets('navigation_test: 从首页跳转到提案页', (tester) async {
    // Arrange
    await initTestLocales();
    await tester.pumpWidget(TestApp(overrides: createTestOverrides(db)));
    await tester.pumpAndSettle();

    // Act - 点击首页 "待确认提案" 快速导航卡片
    await tester.tap(find.text('待确认提案'));
    // pumpAndSettle 等待导航动画 + 异步提案请求快速失败 (maxRetries: 0)
    // 并渲染 ProposalScreen 离线视图
    await tester.pumpAndSettle();

    // Assert - 已跳转到 ProposalScreen
    expect(find.byType(ProposalScreen), findsOneWidget);
    // ProposalScreen AppBar 标题也是 "待确认提案" (首页卡片仍保留在栈中)
    expect(find.text('待确认提案'), findsWidgets);
  });

  /// ----------------------------------------------------------
  /// 测试3: 日程展示测试
  /// 验证首页日程卡片渲染 ("今日 X 项安排")
  /// ----------------------------------------------------------
  testWidgets('schedule_display_test: 首页日程卡片渲染', (tester) async {
    // Arrange
    await initTestLocales();
    await tester.pumpWidget(TestApp(overrides: createTestOverrides(db)));
    await tester.pumpAndSettle();

    // Assert - 日期卡片中包含 "今日 X 项安排" 文本
    expect(find.textContaining('今日'), findsOneWidget);
    // 种子数据无日程, 应显示 "今日 0 项安排"
    expect(find.text('今日 0 项安排'), findsOneWidget);
  });
}
