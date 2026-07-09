// src/lib/weekly_stats.ts
// 周报聚合算法 — 迁移自 Node-RED Flow6 (weekly_report)。
//
// 职责:
//   1. 解析 week 参数: 支持 "YYYY-Www" (ISO 周) 与 "YYYY-MM-DD" (日期) 两种格式
//   2. 计算该周的 start_date (周一) 与 end_date (周日)
//   3. 对 sessions 列表聚合: 总次数 / 专注分钟 / 训练量 / 完成次数 / 完成率

import type { SessionRow } from '../types';

export interface WeekRange {
  week: string;
  startDate: string;
  endDate: string;
}

/** ISO 周计算辅助: 返回给定 Date 所在 ISO 周的 { year, week } */
function getIsoWeek(date: Date): { year: number; week: number } {
  const tmp = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  // 周一为一周第一天: 将日期调整到本周周四
  const dayNum = tmp.getUTCDay() || 7;
  tmp.setUTCDate(tmp.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(tmp.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((tmp.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return { year: tmp.getUTCFullYear(), week };
}

/** 给定 year + ISO week, 返回该周周一的 UTC Date */
function isoWeekToDate(year: number, week: number): Date {
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const jan4Day = jan4.getUTCDay() || 7;
  const week1Monday = new Date(jan4);
  week1Monday.setUTCDate(jan4.getUTCDate() - (jan4Day - 1));
  const monday = new Date(week1Monday);
  monday.setUTCDate(week1Monday.getUTCDate() + (week - 1) * 7);
  return monday;
}

function pad(n: number): string {
  return n.toString().padStart(2, '0');
}

function toDateString(d: Date): string {
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

/**
 * 解析 week 参数为日期范围。
 * - "YYYY-Www" (如 "2026-W28") -> ISO 周
 * - "YYYY-MM-DD" (如 "2026-07-08") -> 该日期所在 ISO 周
 * - 空值 -> 当前周
 */
export function parseWeekRange(week?: string | null): WeekRange {
  let baseDate: Date;
  let label: string;

  if (week && /^\d{4}-W\d{1,2}$/.test(week)) {
    const [yearStr, weekStr] = week.split('-W');
    const year = parseInt(yearStr, 10);
    const w = parseInt(weekStr, 10);
    baseDate = isoWeekToDate(year, w);
    label = `${year}-W${pad(w)}`;
  } else if (week && /^\d{4}-\d{2}-\d{2}$/.test(week)) {
    baseDate = new Date(`${week}T00:00:00Z`);
    const iso = getIsoWeek(baseDate);
    label = `${iso.year}-W${pad(iso.week)}`;
  } else {
    baseDate = new Date();
    const iso = getIsoWeek(baseDate);
    label = `${iso.year}-W${pad(iso.week)}`;
  }

  // 调整到本周周一
  const dayNum = baseDate.getUTCDay() || 7;
  const monday = new Date(baseDate);
  monday.setUTCDate(baseDate.getUTCDate() - (dayNum - 1));
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);

  return {
    week: label,
    startDate: toDateString(monday),
    endDate: toDateString(sunday),
  };
}

export interface WeeklyStatsAggregate {
  week: string;
  start_date: string;
  end_date: string;
  total_sessions: number;
  total_focus_minutes: number;
  total_training_volume: number;
  completed_sessions: number;
  completion_rate: number;
}

/**
 * 聚合周报统计。
 * - total_focus_minutes: 每个 session 约 25 分钟专注, 按完成率折算 (与 Node-RED Flow6 一致)
 * - total_training_volume: 各 session completion_ratio 之和 (简化训练量指标)
 * - completed_sessions: completion_ratio >= 1.0 的次数
 * - completion_rate: completed_sessions / total_sessions
 */
export function aggregateWeeklyStats(
  range: WeekRange,
  sessions: SessionRow[]
): WeeklyStatsAggregate {
  const total = sessions.length;
  const totalFocusMinutes = sessions.reduce(
    (sum, s) => sum + (typeof s.completion_ratio === 'number' ? s.completion_ratio : 0) * 25,
    0
  );
  const totalTrainingVolume = sessions.reduce(
    (sum, s) => sum + (typeof s.completion_ratio === 'number' ? s.completion_ratio : 0),
    0
  );
  const completed = sessions.filter((s) => s.completion_ratio >= 1.0).length;

  return {
    week: range.week,
    start_date: range.startDate,
    end_date: range.endDate,
    total_sessions: total,
    total_focus_minutes: Math.round(totalFocusMinutes),
    total_training_volume: Number(totalTrainingVolume.toFixed(2)),
    completed_sessions: completed,
    completion_rate: total > 0 ? Number((completed / total).toFixed(4)) : 0,
  };
}
