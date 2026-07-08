// 渐进超负荷算法测试
// 测试 functions/progressive_overload.js 中的 calculateProgressiveOverload 函数
const assert = require('assert');
const { extractNamedFunction, loadNodeRedFunction } = require('./test-helper-setup');

describe('Progressive Overload Algorithm', function () {
    let calcFn;
    let runNodeRed;

    before(function () {
        // 提取 calculateProgressiveOverload 命名函数进行单元测试
        calcFn = extractNamedFunction('progressive_overload.js', 'calculateProgressiveOverload');
        // 同时加载完整 Node-RED function（用于集成式验证）
        runNodeRed = loadNodeRedFunction('progressive_overload.js');
    });

    // 测试1: 完成率100% + RPE <= 8 → 递增 2.5kg
    it('应递增2.5kg当完成率100%且RPE<=8', function () {
        const session = { session_id: 1 };
        const exercise = {
            exercise_id: 101,
            planned_sets: 3,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 50.0
        };
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 }
        ];
        const result = calcFn(session, exercise, segments);

        assert.strictEqual(result.newWeight, 52.5);
        assert.strictEqual(result.completionRate, 1.0);
        assert.ok(result.reason.includes('递增'), '原因应包含"递增": ' + result.reason);
    });

    // 测试2: 完成率 < 50% → 退阶 2.5kg
    it('应退阶2.5kg当完成率<50%', function () {
        const session = { session_id: 2 };
        const exercise = {
            exercise_id: 102,
            planned_sets: 4,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 50.0
        };
        // 仅 1 组达到计划次数 → 完成率 1/4 = 25% < 50%
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 5, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 4, rpe: 10 },
            { seg_type: 'WORKOUT_SET', reps_done: 3, rpe: 10 }
        ];
        const result = calcFn(session, exercise, segments);

        assert.strictEqual(result.newWeight, 47.5);
        assert.ok(result.completionRate < 0.5);
        assert.ok(result.reason.includes('退阶'), '原因应包含"退阶": ' + result.reason);
    });

    // 测试3: 完成率 50%-100% 之间 → 维持
    it('应维持当完成率在50%-100%之间', function () {
        const session = { session_id: 3 };
        const exercise = {
            exercise_id: 103,
            planned_sets: 4,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 60.0
        };
        // 2 组达到计划次数 → 完成率 2/4 = 50%，既非 100% 也非 < 50%
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 5, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 4, rpe: 9 }
        ];
        const result = calcFn(session, exercise, segments);

        assert.strictEqual(result.newWeight, 50.0);
        assert.strictEqual(result.completionRate, 0.5);
        assert.ok(result.reason.includes('维持'), '原因应包含"维持": ' + result.reason);
    });

    // 测试4: PR 检测 —— 新重量超过历史最大时为 PR
    it('应检测PR当新重量超过历史最大', function () {
        const session = { session_id: 4 };
        const exercise = {
            exercise_id: 104,
            planned_sets: 3,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 50.0
        };
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 }
        ];
        const result = calcFn(session, exercise, segments);

        // 递增后 52.5 > 50.0 → PR
        assert.strictEqual(result.newWeight, 52.5);
        assert.strictEqual(result.isPR, true);
    });

    // 测试5: 非 PR —— 新重量未超过历史最大
    it('不应检测PR当新重量未超过历史最大', function () {
        const session = { session_id: 5 };
        const exercise = {
            exercise_id: 105,
            planned_sets: 4,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 60.0
        };
        // 维持场景，新重量 50.0 未超过历史最大 60.0
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 5, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 4, rpe: 9 }
        ];
        const result = calcFn(session, exercise, segments);

        assert.strictEqual(result.newWeight, 50.0);
        assert.strictEqual(result.isPR, false);
    });

    // 测试6: RPE > 8 时即使完成率 100% 也应维持（不递增）
    it('RPE>8时即使完成率100%也应维持', function () {
        const session = { session_id: 6 };
        const exercise = {
            exercise_id: 106,
            planned_sets: 3,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 50.0
        };
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 9 }
        ];
        const result = calcFn(session, exercise, segments);

        // 完成率 100% 但平均 RPE 9 > 8 → 维持
        assert.strictEqual(result.completionRate, 1.0);
        assert.strictEqual(result.avgRpe, 9);
        assert.strictEqual(result.newWeight, 50.0);
        assert.ok(result.reason.includes('维持'), '原因应包含"维持": ' + result.reason);
    });

    // 测试7: 退阶重量不应低于 0
    it('退阶重量不应低于0', function () {
        const session = { session_id: 7 };
        const exercise = {
            exercise_id: 107,
            planned_sets: 3,
            planned_reps: 10,
            planned_weight: 1.0,
            max_weight: 1.0
        };
        // 全部未完成 → 完成率 0 < 50% → 退阶
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 0, rpe: 10 },
            { seg_type: 'WORKOUT_SET', reps_done: 0, rpe: 10 },
            { seg_type: 'WORKOUT_SET', reps_done: 0, rpe: 10 }
        ];
        const result = calcFn(session, exercise, segments);

        // Math.max(1.0 - 2.5, 0) = 0
        assert.strictEqual(result.newWeight, 0);
        assert.ok(result.newWeight >= 0, '退阶后重量不应为负');
    });

    // 测试8: 应生成正确的提案(proposal)结构
    it('应生成正确的提案结构', function () {
        const session = { session_id: 8 };
        const exercise = {
            exercise_id: 108,
            planned_sets: 3,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 50.0
        };
        const segments = [
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
            { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 }
        ];
        const result = calcFn(session, exercise, segments);
        const proposal = result.proposal;

        assert.strictEqual(proposal.type, 'PROPOSAL');
        assert.strictEqual(proposal.lock_state, 'LOCKED');
        assert.strictEqual(proposal.target_table, 'workout_exercise');
        assert.strictEqual(proposal.target_id, exercise.exercise_id);
        assert.strictEqual(proposal.target_field, 'planned_weight');
        assert.strictEqual(proposal.old_value, exercise.planned_weight);
        assert.strictEqual(proposal.new_value, result.newWeight);
        assert.ok(proposal.created_at, 'created_at 应存在');
    });

    // 测试9: 空 segments 数组应安全处理（完成率 0，退阶）
    it('空segments数组应安全处理', function () {
        const session = { session_id: 9 };
        const exercise = {
            exercise_id: 109,
            planned_sets: 3,
            planned_reps: 10,
            planned_weight: 50.0,
            max_weight: 50.0
        };
        const result = calcFn(session, exercise, []);

        // 无完成组 → 完成率 0 < 50% → 退阶
        assert.strictEqual(result.completionRate, 0);
        assert.strictEqual(result.newWeight, 47.5);
        // 无 RPE 数据时平均 RPE 默认为 5
        assert.strictEqual(result.avgRpe, 5);
    });

    // 测试10: 通过 Node-RED msg 流程的集成式验证
    it('应能通过Node-RED msg流程正确处理', function () {
        const msg = {
            payload: {
                session: { session_id: 10 },
                exercise: {
                    exercise_id: 110,
                    planned_sets: 3,
                    planned_reps: 10,
                    planned_weight: 50.0,
                    max_weight: 50.0
                },
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
                    { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 },
                    { seg_type: 'WORKOUT_SET', reps_done: 10, rpe: 7 }
                ]
            }
        };
        const result = runNodeRed(msg);

        assert.strictEqual(result.payload.newWeight, 52.5);
        assert.strictEqual(result.payload.isPR, true);
        assert.ok(result.payload.proposal, '应生成提案');
    });
});
