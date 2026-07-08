// 冲突检测函数（Node-RED function 节点代码）
// 输入: msg.payload = { new_entry: {...}, existing_entries: [...] }
// 输出: msg.payload.conflicts, msg.payload.resolved, msg.payload.proposals
var newEntry = msg.payload.new_entry;
var existing = msg.payload.existing_entries || [];

var conflicts = existing.filter(function(e) {
    return e.date === newEntry.date && e.start_time === newEntry.start_time;
});

var proposals = [];

if (conflicts.length > 0) {
    // 按优先级排序（数字越小优先级越高）
    var allEntries = conflicts.concat([newEntry]);
    allEntries.sort(function(a, b) {
        return (a.priority || 5) - (b.priority || 5);
    });

    // 低优先级项顺延到下一个空档
    for (var i = 1; i < allEntries.length; i++) {
        var entry = allEntries[i];
        var newTime = addMinutes(entry.start_time, 60);
        proposals.push({
            type: 'PROPOSAL',
            lock_state: 'LOCKED',
            target_table: 'schedule_entry',
            target_id: entry.entry_id,
            target_field: 'start_time',
            old_value: entry.start_time,
            new_value: newTime,
            reason: '时段冲突，自动顺延到 ' + newTime,
            created_at: new Date().toISOString()
        });
    }
}

msg.payload.conflicts = conflicts;
msg.payload.proposals = proposals;
msg.payload.resolved = proposals.length > 0;
return msg;

function addMinutes(timeStr, minutes) {
    var parts = timeStr.split(':');
    var h = parseInt(parts[0]);
    var m = parseInt(parts[1]) + minutes;
    h += Math.floor(m / 60);
    m = m % 60;
    return ('0' + h).slice(-2) + ':' + ('0' + m).slice(-2);
}
