// 周报模板填充函数（Node-RED function 节点代码）
// 输入: msg.payload = { weekly_sessions: [...], goals: [...] }
// 输出: msg.payload.report (格式化文本)
var sessions = msg.payload.weekly_sessions || [];
var goals = msg.payload.goals || [];

// 统计
var focusSessions = sessions.filter(function(s) { return s.exec_mode === 'FOCUS'; });
var workoutSessions = sessions.filter(function(s) { return s.exec_mode === 'WORKOUT'; });

var totalFocusMinutes = focusSessions.reduce(function(sum, s) {
    return sum + (s.actual_seconds || 0) / 60;
}, 0);

var totalWorkoutVolume = 0;
var completedWorkouts = workoutSessions.filter(function(s) { return s.state === 'COMPLETED'; }).length;

var avgCompletion = sessions.length > 0 ?
    sessions.reduce(function(sum, s) { return sum + (s.completion_ratio || 0); }, 0) / sessions.length : 0;

// 生成周报文本
var week = getWeekString(new Date());
var report = '📊 第' + week + '周 复盘报告\n\n';
report += '━━━ 专注学习 ━━━\n';
report += '番茄完成: ' + focusSessions.length + ' 次\n';
report += '专注时长: ' + Math.round(totalFocusMinutes) + ' 分钟\n\n';
report += '━━━ 健身训练 ━━━\n';
report += '完成训练: ' + completedWorkouts + ' 次\n';
report += '平均完成率: ' + (avgCompletion * 100).toFixed(0) + '%\n\n';

if (goals.length > 0) {
    report += '━━━ 目标进度 ━━━\n';
    goals.forEach(function(g) {
        var pct = g.target_value > 0 ? (g.current_value / g.target_value * 100).toFixed(0) : 0;
        report += g.title + ': ' + g.current_value + '/' + g.target_value + g.unit + ' (' + pct + '%)\n';
    });
}

report += '\n💪 下周继续加油！';

msg.payload.report = report;
return msg;

function getWeekString(d) {
    var date = new Date(d);
    date.setHours(0, 0, 0, 0);
    date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7);
    var week1 = new Date(date.getFullYear(), 0, 4);
    return 1 + Math.round(((date - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7) + '';
}
