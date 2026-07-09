// src/lib/progressive_overload.ts
// 渐进超负荷算法 — 迁移自 Node-RED functions/progressive_overload.js (Flow2)。
//
// 决策规则 (与 Node-RED Flow2 一致):
//   completionRatio >= 1.0 && avgRpe <= 8  → +2.5kg (递增)
//   completionRatio < 0.5                   → -2.5kg (退阶, 不低于 0)
//   其他                                     → 维持
//
// 输入:
//   - exercise: 训练动作 (含 planned_weight / exercise_id 等)
//   - completionRatio: 完成率 (0~1), 由调用方 (handler) 从请求体传入
//   - segments: session 片段, 仅 WORKOUT_SET 类型参与平均 RPE 计算
// 输出: { newWeight, reason, isPR, completionRatio, avgRpe, proposal }

import type {
  WorkoutExercise,
  SessionSegment,
  ProgressiveOverloadResult,
  ProposalInsert,
} from '../types';

const STEP_KG = 2.5;

/** 从 WORKOUT_SET 片段计算平均 RPE (无数据时默认 5, 与 Node-RED 一致) */
export function computeAvgRpe(segments: SessionSegment[]): number {
  const rpeValues = segments
    .filter((s) => s.seg_type === 'WORKOUT_SET' && s.rpe != null)
    .map((s) => s.rpe as number);
  if (rpeValues.length === 0) return 5;
  return rpeValues.reduce((a, b) => a + b, 0) / rpeValues.length;
}

/**
 * 计算渐进超负荷。
 * @param exercise         训练动作
 * @param completionRatio  完成率 (0~1)
 * @param segments         训练片段 (用于平均 RPE)
 */
export function progressiveOverload(
  exercise: WorkoutExercise,
  completionRatio: number,
  segments: SessionSegment[]
): ProgressiveOverloadResult {
  const avgRpe = computeAvgRpe(segments);
  const plannedWeight = exercise.planned_weight;
  let newWeight = plannedWeight;
  let reason = '';

  if (completionRatio >= 1.0 && avgRpe <= 8) {
    newWeight = plannedWeight + STEP_KG;
    reason = `完成率100%，RPE ${avgRpe.toFixed(1)}，递增${STEP_KG}kg`;
  } else if (completionRatio < 0.5) {
    newWeight = Math.max(plannedWeight - STEP_KG, 0);
    reason = `完成率${(completionRatio * 100).toFixed(0)}%，退阶${STEP_KG}kg`;
  } else {
    reason = `完成率${(completionRatio * 100).toFixed(0)}%，维持${plannedWeight}kg`;
  }

  const maxWeight = exercise.max_weight ?? 0;
  const isPR = newWeight > maxWeight;

  const proposal: ProposalInsert = {
    type: 'PROPOSAL',
    lock_state: 'LOCKED',
    target_table: 'workout_exercise',
    target_id: exercise.exercise_id,
    target_field: 'planned_weight',
    old_value: String(plannedWeight),
    new_value: String(newWeight),
    reason,
    created_at: new Date().toISOString(),
  };

  return {
    newWeight,
    reason,
    isPR,
    completionRatio,
    avgRpe,
    proposal,
  };
}
