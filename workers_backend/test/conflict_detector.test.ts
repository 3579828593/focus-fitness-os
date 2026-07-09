// test/conflict_detector.test.ts
// 冲突检测算法单元测试 — 迁移自 Node-RED conflict_resolver.test.js。
//
// 覆盖:
//   1. 同时段冲突 -> 生成顺延提案
//   2. 无冲突 -> 空数组

import { describe, it, expect } from 'vitest';
import { detectConflicts, addMinutes } from '../src/lib/conflict_detector';
import type { ScheduleEntry } from '../src/types';

describe('detectConflicts', () => {
  it('同时段冲突 -> 应生成顺延提案', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      priority: 3, // 更高优先级 (数字越小越高)
    };
    const existing: ScheduleEntry[] = [
      {
        entry_id: 1,
        unit_id: 2,
        date: '2026-07-08',
        start_time: '09:00',
        priority: 5, // 低优先级 -> 被顺延
      },
    ];

    const result = detectConflicts(newEntry, existing);

    expect(result.conflicts.length).toBe(1);
    expect(result.proposals.length).toBe(1);
    expect(result.resolved).toBe(true);

    const proposal = result.proposals[0];
    expect(proposal.target_id).toBe(1); // 低优先级被顺延
    expect(proposal.old_value).toBe('09:00');
    expect(proposal.new_value).toBe('10:00'); // +60min
    expect(proposal.type).toBe('PROPOSAL');
    expect(proposal.lock_state).toBe('LOCKED');
    expect(proposal.target_table).toBe('schedule_entry');
    expect(proposal.target_field).toBe('start_time');
    expect(proposal.reason).toContain('冲突');
  });

  it('无冲突 -> 应返回空数组', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      priority: 3,
    };
    const existing: ScheduleEntry[] = [
      // 同日不同时间
      { entry_id: 1, unit_id: 2, date: '2026-07-08', start_time: '10:00', priority: 5 },
      // 同时间不同日
      { entry_id: 2, unit_id: 3, date: '2026-07-09', start_time: '09:00', priority: 5 },
    ];

    const result = detectConflicts(newEntry, existing);

    expect(result.conflicts.length).toBe(0);
    expect(result.proposals.length).toBe(0);
    expect(result.resolved).toBe(false);
  });

  it('多个冲突时应按优先级排序, 高优先级保留, 其余顺延', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      priority: 1, // 最高优先级
    };
    const existing: ScheduleEntry[] = [
      { entry_id: 1, unit_id: 2, date: '2026-07-08', start_time: '09:00', priority: 5 },
      { entry_id: 2, unit_id: 3, date: '2026-07-08', start_time: '09:00', priority: 3 },
    ];

    const result = detectConflicts(newEntry, existing);

    expect(result.conflicts.length).toBe(2);
    expect(result.proposals.length).toBe(2);

    // 最高优先级 (100, priority=1) 不应被顺延
    const postponedIds = result.proposals.map((p) => p.target_id);
    expect(postponedIds).toContain(1);
    expect(postponedIds).toContain(2);
    expect(postponedIds).not.toContain(100);
  });

  it('existing 为空数组时无冲突', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      priority: 3,
    };
    const result = detectConflicts(newEntry, []);
    expect(result.conflicts.length).toBe(0);
    expect(result.proposals.length).toBe(0);
    expect(result.resolved).toBe(false);
  });

  it('existing 为 null/undefined 时应安全处理', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      priority: 3,
    };
    const r1 = detectConflicts(newEntry, null);
    const r2 = detectConflicts(newEntry, undefined);
    expect(r1.conflicts.length).toBe(0);
    expect(r2.proposals.length).toBe(0);
  });

  it('优先级缺失时应使用默认值 5', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      // 无 priority
    };
    const existing: ScheduleEntry[] = [
      { entry_id: 1, unit_id: 2, date: '2026-07-08', start_time: '09:00' },
    ];
    const result = detectConflicts(newEntry, existing);
    expect(result.conflicts.length).toBe(1);
    expect(result.proposals.length).toBe(1);
  });

  it('仅日期相同但时间不同不应视为冲突', () => {
    const newEntry: ScheduleEntry = {
      entry_id: 100,
      unit_id: 1,
      date: '2026-07-08',
      start_time: '09:00',
      priority: 3,
    };
    const existing: ScheduleEntry[] = [
      { entry_id: 1, unit_id: 2, date: '2026-07-08', start_time: '09:01', priority: 5 },
    ];
    const result = detectConflicts(newEntry, existing);
    expect(result.conflicts.length).toBe(0);
  });
});

describe('addMinutes', () => {
  it('应正确计算跨小时顺延', () => {
    expect(addMinutes('09:00', 60)).toBe('10:00');
    expect(addMinutes('09:30', 60)).toBe('10:30');
    expect(addMinutes('23:30', 60)).toBe('00:30');
  });
});
