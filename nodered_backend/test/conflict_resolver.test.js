// 冲突检测测试
// 测试 functions/conflict_resolver.js（Node-RED function 节点代码）
// 该函数直接操作 msg，检测日程冲突并生成顺延提案
const assert = require('assert');
const { loadNodeRedFunction } = require('./test-helper-setup');

describe('Conflict Resolver', function () {
    let fn;

    before(function () {
        // 加载 Node-RED function 代码为 fn(msg)
        fn = loadNodeRedFunction('conflict_resolver.js');
    });

    // 测试1: 无冲突场景
    it('应返回空冲突当无时间冲突', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 3 },
                existing_entries: [
                    // 同日不同时间
                    { entry_id: 1, date: '2026-07-08', start_time: '10:00', priority: 5 },
                    // 同时间不同日
                    { entry_id: 2, date: '2026-07-09', start_time: '09:00', priority: 5 }
                ]
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.conflicts.length, 0);
        assert.strictEqual(result.payload.proposals.length, 0);
        assert.strictEqual(result.payload.resolved, false);
    });

    // 测试2: 时间冲突场景（单一冲突）
    it('应检测到单一时间冲突并生成顺延提案', function () {
        const msg = {
            payload: {
                // 新条目优先级更高(3 < 5)，应保留
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 3 },
                existing_entries: [
                    // 与新条目同日同时段
                    { entry_id: 1, date: '2026-07-08', start_time: '09:00', priority: 5 }
                ]
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.conflicts.length, 1);
        assert.strictEqual(result.payload.proposals.length, 1);
        assert.strictEqual(result.payload.resolved, true);

        // 低优先级(entry_id:1)被顺延，高优先级(new_entry:100)保留
        const proposal = result.payload.proposals[0];
        assert.strictEqual(proposal.target_id, 1);
        assert.strictEqual(proposal.old_value, '09:00');
        // 顺延 60 分钟 → 10:00
        assert.strictEqual(proposal.new_value, '10:00');
    });

    // 测试3: 多个冲突时按优先级排序
    it('多个冲突时应按优先级排序顺延低优先级项', function () {
        const msg = {
            payload: {
                // 新条目优先级最高(1)
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 1 },
                existing_entries: [
                    { entry_id: 1, date: '2026-07-08', start_time: '09:00', priority: 5 },
                    { entry_id: 2, date: '2026-07-08', start_time: '09:00', priority: 3 }
                ]
            }
        };
        const result = fn(msg);

        // 两个冲突项
        assert.strictEqual(result.payload.conflicts.length, 2);
        // 排序后最高优先级(new_entry)保留，其余 2 项顺延
        assert.strictEqual(result.payload.proposals.length, 2);
        assert.strictEqual(result.payload.resolved, true);

        // 被顺延的应为 entry_id 1 和 2，最高优先级的 100 不被顺延
        const postponedIds = result.payload.proposals.map(function (p) { return p.target_id; });
        assert.ok(postponedIds.indexOf(1) !== -1, 'entry_id 1 应被顺延');
        assert.ok(postponedIds.indexOf(2) !== -1, 'entry_id 2 应被顺延');
        assert.ok(postponedIds.indexOf(100) === -1, 'entry_id 100(最高优先级)不应被顺延');
    });

    // 测试4: 边界 —— existing_entries 为空数组
    it('existing_entries为空数组时应无冲突', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 3 },
                existing_entries: []
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.conflicts.length, 0);
        assert.strictEqual(result.payload.proposals.length, 0);
        assert.strictEqual(result.payload.resolved, false);
    });

    // 测试5: 边界 —— existing_entries 字段缺失
    it('existing_entries缺失时应安全处理为空数组', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 3 }
                // 无 existing_entries 字段
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.conflicts.length, 0);
        assert.strictEqual(result.payload.resolved, false);
    });

    // 测试6: 边界 —— 优先级相同(均缺失)时使用默认值 5
    it('优先级缺失时应使用默认值5并仍能解决冲突', function () {
        const msg = {
            payload: {
                // 两项均无 priority 字段 → 默认 5
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00' },
                existing_entries: [
                    { entry_id: 1, date: '2026-07-08', start_time: '09:00' }
                ]
            }
        };
        const result = fn(msg);

        // 仍检测到冲突并生成 1 个顺延提案
        assert.strictEqual(result.payload.conflicts.length, 1);
        assert.strictEqual(result.payload.proposals.length, 1);
        assert.strictEqual(result.payload.resolved, true);
    });

    // 测试7: addMinutes 跨小时计算正确性
    it('addMinutes应正确计算跨小时顺延时间', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:30', priority: 1 },
                existing_entries: [
                    { entry_id: 1, date: '2026-07-08', start_time: '09:30', priority: 5 }
                ]
            }
        };
        const result = fn(msg);

        // 09:30 + 60 分钟 = 10:30
        assert.strictEqual(result.payload.proposals[0].new_value, '10:30');
    });

    // 测试8: 应生成正确的提案结构
    it('应生成正确的提案结构', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '14:00', priority: 3 },
                existing_entries: [
                    { entry_id: 1, date: '2026-07-08', start_time: '14:00', priority: 5 }
                ]
            }
        };
        const result = fn(msg);
        const proposal = result.payload.proposals[0];

        assert.strictEqual(proposal.type, 'PROPOSAL');
        assert.strictEqual(proposal.lock_state, 'LOCKED');
        assert.strictEqual(proposal.target_table, 'schedule_entry');
        assert.strictEqual(proposal.target_field, 'start_time');
        assert.ok(proposal.reason.indexOf('冲突') !== -1, '原因应包含"冲突": ' + proposal.reason);
        assert.ok(proposal.created_at, 'created_at 应存在');
    });

    // 测试9: 仅日期相同但时间不同不应视为冲突
    it('仅日期相同但时间不同不应视为冲突', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 3 },
                existing_entries: [
                    { entry_id: 1, date: '2026-07-08', start_time: '09:01', priority: 5 }
                ]
            }
        };
        const result = fn(msg);

        // 09:00 != 09:01 → 无冲突
        assert.strictEqual(result.payload.conflicts.length, 0);
        assert.strictEqual(result.payload.resolved, false);
    });

    // 测试10: 仅时间相同但日期不同不应视为冲突
    it('仅时间相同但日期不同不应视为冲突', function () {
        const msg = {
            payload: {
                new_entry: { entry_id: 100, date: '2026-07-08', start_time: '09:00', priority: 3 },
                existing_entries: [
                    { entry_id: 1, date: '2026-07-07', start_time: '09:00', priority: 5 }
                ]
            }
        };
        const result = fn(msg);

        assert.strictEqual(result.payload.conflicts.length, 0);
        assert.strictEqual(result.payload.resolved, false);
    });
});
