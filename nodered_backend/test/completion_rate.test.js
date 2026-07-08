// 完成率计算测试
// 测试 functions/completion_rate.js（Node-RED function 节点代码）
// 该函数直接操作 msg，计算 completion_rate / total_volume / completed_sets
const assert = require('assert');
const { loadNodeRedFunction } = require('./test-helper-setup');

describe('Completion Rate Calculation', function () {
    let fn;

    before(function () {
        // 加载 Node-RED function 代码为 fn(msg)
        fn = loadNodeRedFunction('completion_rate.js');
    });

    // 测试1: 全部完成的场景
    it('应正确计算全部完成的完成率与训练量', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 50 },
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 50 },
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 50 }
                ],
                planned_sets: 3
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.completed_sets, 3);
        assert.strictEqual(result.payload.completion_rate, 1);
        // 训练量 = 10*50 * 3 = 1500
        assert.strictEqual(result.payload.total_volume, 1500);
    });

    // 测试2: 部分完成的场景
    it('应正确计算部分完成的完成率与训练量', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 50 },
                    { seg_type: 'WORKOUT_SET', reps_done: 5, weight_kg_done: 50 },
                    // reps_done 为 null 的组不计入完成组
                    { seg_type: 'WORKOUT_SET', reps_done: null, weight_kg_done: 50 }
                ],
                planned_sets: 3
            }
        };
        const result = fn(msg);

        // 完成组 = 2（reps_done 非 null 的组）
        assert.strictEqual(result.payload.completed_sets, 2);
        // 完成率 = 2/3
        assert.ok(Math.abs(result.payload.completion_rate - (2 / 3)) < 0.0001,
            '完成率应约为 2/3，实际: ' + result.payload.completion_rate);
        // 训练量 = 10*50 + 5*50 + 0*50(null||0) = 750
        assert.strictEqual(result.payload.total_volume, 750);
    });

    // 测试3: 未完成任何组的场景
    it('应返回0完成率当未完成任何组', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: null, weight_kg_done: 50 },
                    { seg_type: 'WORKOUT_SET', reps_done: null, weight_kg_done: 50 }
                ],
                planned_sets: 2
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.completed_sets, 0);
        assert.strictEqual(result.payload.completion_rate, 0);
        // reps_done 为 null → 0，训练量为 0
        assert.strictEqual(result.payload.total_volume, 0);
    });

    // 测试4: 空数组场景
    it('应返回0当segments为空数组', function () {
        const msg = {
            payload: {
                segments: [],
                planned_sets: 3
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.completed_sets, 0);
        assert.strictEqual(result.payload.completion_rate, 0);
        // reduce 初始值为 0
        assert.strictEqual(result.payload.total_volume, 0);
    });

    // 测试5: planned_sets 为 0 时不应除零
    it('planned_sets为0时完成率应为0避免除零', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 50 }
                ],
                planned_sets: 0
            }
        };
        const result = fn(msg);

        // plannedSets > 0 为 false → completion_rate = 0
        assert.strictEqual(result.payload.completion_rate, 0);
        // 仍统计完成组数
        assert.strictEqual(result.payload.completed_sets, 1);
        assert.strictEqual(result.payload.total_volume, 500);
    });

    // 测试6: 应忽略非 WORKOUT_SET 类型的片段
    it('应忽略非WORKOUT_SET类型的片段', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'REST', reps_done: 10, weight_kg_done: 50 },
                    { seg_type: 'WARMUP', reps_done: 10, weight_kg_done: 50 },
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 50 }
                ],
                planned_sets: 1
            }
        };
        const result = fn(msg);

        // 仅 1 个 WORKOUT_SET 完成组
        assert.strictEqual(result.payload.completed_sets, 1);
        assert.strictEqual(result.payload.completion_rate, 1);
        // 训练量仅计入 WORKOUT_SET = 500
        assert.strictEqual(result.payload.total_volume, 500);
    });

    // 测试7: 缺失字段时使用默认值
    it('缺失segments与planned_sets时应使用默认值', function () {
        const msg = { payload: {} };
        const result = fn(msg);

        // segments 默认 []，planned_sets 默认 0
        assert.strictEqual(result.payload.completed_sets, 0);
        assert.strictEqual(result.payload.completion_rate, 0);
        assert.strictEqual(result.payload.total_volume, 0);
    });

    // 测试8: weight_kg_done 缺失时按 0 计算训练量
    it('weight_kg_done缺失时训练量应按0计算', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: 10 },
                    { seg_type: 'WORKOUT_SET', reps_done: 10, weight_kg_done: 40 }
                ],
                planned_sets: 2
            }
        };
        const result = fn(msg);

        // 训练量 = 10*0 + 10*40 = 400
        assert.strictEqual(result.payload.completed_sets, 2);
        assert.strictEqual(result.payload.completion_rate, 1);
        assert.strictEqual(result.payload.total_volume, 400);
    });

    // 测试9: reps_done 为 0 但非 null 应计入完成组
    it('reps_done为0但非null应计入完成组', function () {
        const msg = {
            payload: {
                segments: [
                    { seg_type: 'WORKOUT_SET', reps_done: 0, weight_kg_done: 50 }
                ],
                planned_sets: 2
            }
        };
        const result = fn(msg);

        // reps_done 为 0，0 != null 为 true → 计入完成组
        assert.strictEqual(result.payload.completed_sets, 1);
        assert.strictEqual(result.payload.completion_rate, 0.5);
        // 训练量 = 0 * 50 = 0
        assert.strictEqual(result.payload.total_volume, 0);
    });
});
