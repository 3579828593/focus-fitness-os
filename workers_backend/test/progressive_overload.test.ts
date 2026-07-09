// test/progressive_overload.test.ts
// 渐进超负荷算法单元测试 — 迁移自 Node-RED progressive_overload.test.js。
//
// 决策规则:
//   completionRatio >= 1.0 && avgRpe <= 8 -> +2.5kg
//   completionRatio < 0.5                 -> -2.5kg (不低于 0)
//   其他                                   -> 维持

import { describe, it, expect } from 'vitest';
import { progressiveOverload, computeAvgRpe } from '../src/lib/progressive_overload';
import type { WorkoutExercise, SessionSegment } from '../src/types';

function makeExercise(plannedWeight = 50): WorkoutExercise {
  return {
    exercise_id: 101,
    unit_id: 1,
    name: 'Bench Press',
    planned_sets: 3,
    planned_reps: 10,
    planned_weight: plannedWeight,
    max_weight: plannedWeight,
  };
}

function rpeSegments(rpe: number, count = 3): SessionSegment[] {
  return Array.from({ length: count }, () => ({
    seg_type: 'WORKOUT_SET',
    reps_done: 10,
    rpe,
  }));
}

describe('progressiveOverload', () => {
  it('completionRatio=1.0 且 rpe=7 -> +2.5kg', () => {
    const exercise = makeExercise(50);
    const result = progressiveOverload(exercise, 1.0, rpeSegments(7));
    expect(result.newWeight).toBe(52.5);
    expect(result.completionRatio).toBe(1.0);
    expect(result.avgRpe).toBe(7);
    expect(result.reason).toContain('递增');
    // 递增至 52.5 > max_weight 50 -> PR
    expect(result.isPR).toBe(true);
  });

  it('completionRatio=0.4 -> -2.5kg (退阶)', () => {
    const exercise = makeExercise(50);
    const result = progressiveOverload(exercise, 0.4, rpeSegments(9));
    expect(result.newWeight).toBe(47.5);
    expect(result.completionRatio).toBe(0.4);
    expect(result.reason).toContain('退阶');
  });

  it('completionRatio=0.8 -> 维持', () => {
    const exercise = makeExercise(50);
    const result = progressiveOverload(exercise, 0.8, rpeSegments(7));
    expect(result.newWeight).toBe(50);
    expect(result.completionRatio).toBe(0.8);
    expect(result.reason).toContain('维持');
  });

  it('completionRatio=1.0 但 rpe=9 (>8) -> 维持', () => {
    const exercise = makeExercise(50);
    const result = progressiveOverload(exercise, 1.0, rpeSegments(9));
    expect(result.newWeight).toBe(50);
    expect(result.avgRpe).toBe(9);
    expect(result.reason).toContain('维持');
  });

  it('退阶后重量不应低于 0', () => {
    const exercise = makeExercise(1);
    const result = progressiveOverload(exercise, 0.0, rpeSegments(10));
    expect(result.newWeight).toBe(0);
    expect(result.newWeight).toBeGreaterThanOrEqual(0);
  });

  it('应生成正确的 LOCKED 提案结构', () => {
    const exercise = makeExercise(50);
    const result = progressiveOverload(exercise, 1.0, rpeSegments(7));
    const proposal = result.proposal;
    expect(proposal.type).toBe('PROPOSAL');
    expect(proposal.lock_state).toBe('LOCKED');
    expect(proposal.target_table).toBe('workout_exercise');
    expect(proposal.target_id).toBe(exercise.exercise_id);
    expect(proposal.target_field).toBe('planned_weight');
    expect(proposal.old_value).toBe('50');
    expect(proposal.new_value).toBe('52.5');
    expect(proposal.created_at).toBeTruthy();
  });

  it('空 segments 数组应安全处理 (avgRpe 默认 5)', () => {
    const exercise = makeExercise(50);
    const result = progressiveOverload(exercise, 0.0, []);
    // completionRatio 0 < 0.5 -> 退阶
    expect(result.avgRpe).toBe(5);
    expect(result.newWeight).toBe(47.5);
  });
});

describe('computeAvgRpe', () => {
  it('仅 WORKOUT_SET 片段参与计算', () => {
    const segments: SessionSegment[] = [
      { seg_type: 'WARMUP', rpe: 3 },
      { seg_type: 'WORKOUT_SET', rpe: 7 },
      { seg_type: 'WORKOUT_SET', rpe: 9 },
      { seg_type: 'COOLDOWN', rpe: 2 },
    ];
    expect(computeAvgRpe(segments)).toBe(8); // (7+9)/2
  });

  it('无 RPE 数据时默认 5', () => {
    expect(computeAvgRpe([])).toBe(5);
    expect(computeAvgRpe([{ seg_type: 'WORKOUT_SET' }])).toBe(5);
  });
});
