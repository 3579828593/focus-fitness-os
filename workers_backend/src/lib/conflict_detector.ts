// src/lib/conflict_detector.ts
// 冲突检测算法 — 迁移自 Node-RED functions/conflict_resolver.js (Flow4)。
//
// 逻辑:
//   1. 在 existing 中找出与 newEntry 同日同时段的条目 -> conflicts
//      (同时校验 date 与 start_time, 避免调用方未预过滤时误判)
//   2. 若存在冲突, 将 conflicts + [newEntry] 按优先级升序排序 (priority 越小越高, 默认 5)
//   3. 排序后最高优先级保留, 其余顺延 60min × index (index 从 1 开始)
//   4. 为每个被顺延的条目生成一个 LOCKED 提案

import type {
  ScheduleEntry,
  ConflictDetectionResult,
  ProposalInsert,
} from '../types';

/** 给 "HH:MM" 增加指定分钟, 返回新的 "HH:MM" (支持跨小时/跨日回绕) */
export function addMinutes(timeStr: string, minutes: number): string {
  const parts = timeStr.split(':');
  let h = parseInt(parts[0], 10);
  let m = parseInt(parts[1], 10) + minutes;
  h += Math.floor(m / 60);
  m = m % 60;
  if (h >= 24) h -= 24; // 跨日回绕 (与 Node-RED Flow4 一致)
  return ('0' + h).slice(-2) + ':' + ('0' + m).slice(-2);
}

/** 优先级取值 (缺省 5, 数字越小优先级越高) */
function priorityOf(entry: ScheduleEntry): number {
  return typeof entry.priority === 'number' ? entry.priority : 5;
}

/**
 * 检测日程冲突并生成顺延提案。
 * @param newEntry        新增/变更的日程条目
 * @param existingEntries 同期已存在的日程条目 (通常为同日查询结果); 允许 null/undefined
 */
export function detectConflicts(
  newEntry: ScheduleEntry,
  existingEntries: ScheduleEntry[] | undefined | null
): ConflictDetectionResult {
  const existing = existingEntries ?? [];

  // 同时段冲突: 同 date 且同 start_time
  const conflicts = existing.filter(
    (e) => e.date === newEntry.date && e.start_time === newEntry.start_time
  );

  const proposals: ProposalInsert[] = [];

  if (conflicts.length > 0) {
    // 合并并按优先级升序排序 (稳定)
    const allEntries = [...conflicts, newEntry].sort((a, b) => priorityOf(a) - priorityOf(b));

    // 索引 0 (最高优先级) 保留, 其余顺延 60min × index
    for (let i = 1; i < allEntries.length; i++) {
      const entry = allEntries[i];
      const newTime = addMinutes(entry.start_time, 60 * i);
      proposals.push({
        type: 'PROPOSAL',
        lock_state: 'LOCKED',
        target_table: 'schedule_entry',
        target_id: entry.entry_id,
        target_field: 'start_time',
        old_value: entry.start_time,
        new_value: newTime,
        reason: `时段冲突，自动顺延到 ${newTime}`,
        created_at: new Date().toISOString(),
      });
    }
  }

  return {
    conflicts,
    proposals,
    resolved: proposals.length > 0,
  };
}
