// 渐进超负荷算法（Node-RED function 节点代码）
// 输入: msg.payload = { session: {...}, exercise: {...}, segments: [...] }
// 输出: msg.payload = { newWeight, reason, proposal }
function calculateProgressiveOverload(session, exercise, segments) {
    // 计算完成率
    var completedSets = segments.filter(function(s) {
        return s.seg_type === 'WORKOUT_SET' && s.reps_done >= exercise.planned_reps;
    }).length;
    var completionRate = completedSets / exercise.planned_sets;

    // 计算平均RPE
    var rpeValues = segments.filter(function(s) { return s.rpe != null; }).map(function(s) { return s.rpe; });
    var avgRpe = rpeValues.length > 0 ? rpeValues.reduce(function(a,b){return a+b;}) / rpeValues.length : 5;

    var newWeight = exercise.planned_weight;
    var reason = '';

    if (completionRate === 1.0 && avgRpe <= 8) {
        newWeight = exercise.planned_weight + 2.5;
        reason = '完成率100%，RPE ' + avgRpe.toFixed(1) + '，递增2.5kg';
    } else if (completionRate < 0.5) {
        newWeight = Math.max(exercise.planned_weight - 2.5, 0);
        reason = '完成率' + (completionRate * 100).toFixed(0) + '%，退阶2.5kg';
    } else {
        reason = '完成率' + (completionRate * 100).toFixed(0) + '%，维持' + exercise.planned_weight + 'kg';
    }

    // PR检测
    var isPR = newWeight > (exercise.max_weight || 0);

    return {
        newWeight: newWeight,
        reason: reason,
        isPR: isPR,
        completionRate: completionRate,
        avgRpe: avgRpe,
        proposal: {
            type: 'PROPOSAL',
            lock_state: 'LOCKED',
            target_table: 'workout_exercise',
            target_id: exercise.exercise_id,
            target_field: 'planned_weight',
            old_value: exercise.planned_weight,
            new_value: newWeight,
            reason: reason,
            created_at: new Date().toISOString()
        }
    };
}

var result = calculateProgressiveOverload(
    msg.payload.session,
    msg.payload.exercise,
    msg.payload.segments || []
);
msg.payload = result;
return msg;
