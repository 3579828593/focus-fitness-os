// 完成率统计函数（Node-RED function 节点代码）
// 输入: msg.payload = { segments: [...], planned_sets: N }
// 输出: msg.payload.completion_rate, msg.payload.total_volume
var segments = msg.payload.segments || [];
var plannedSets = msg.payload.planned_sets || 0;

var completedSets = segments.filter(function(s) {
    return s.seg_type === 'WORKOUT_SET' && s.reps_done != null;
}).length;

var totalVolume = segments
    .filter(function(s) { return s.seg_type === 'WORKOUT_SET'; })
    .reduce(function(sum, s) {
        return sum + (s.reps_done || 0) * (s.weight_kg_done || 0);
    }, 0);

msg.payload.completion_rate = plannedSets > 0 ? completedSets / plannedSets : 0;
msg.payload.total_volume = totalVolume;
msg.payload.completed_sets = completedSets;
return msg;
