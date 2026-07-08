// Node-RED 测试环境配置
// 使用 node-red-node-test-helper 进行 function 节点测试
//
// 说明: functions/ 目录下的文件均为 Node-RED function 节点代码，
// 它们不是 CommonJS 模块（直接使用 msg 变量并以 return msg 结尾），
// 因此不能通过 require() 直接加载。本文件提供两种加载方式：
//   1. loadNodeRedFunction(filename)  —— 将整段代码包装为 fn(msg) 调用
//   2. extractNamedFunction(filename) —— 提取文件内定义的独立命名函数
const path = require('path');
const fs = require('fs');
const vm = require('vm');

// 尝试加载 node-red-node-test-helper（可选依赖）
// 纯函数测试无需启动 Node-RED 服务，未安装时提供空实现以保证测试可运行
let helper;
try {
    helper = require('node-red-node-test-helper');
} catch (e) {
    helper = {
        startServer: function (cb) { if (cb) { cb(); } },
        stopServer: function (cb) { if (cb) { cb(); } },
        load: function () {},
        unload: function () {}
    };
}

// 读取 function 文件的原始代码
function loadFunctionCode(filename) {
    return fs.readFileSync(path.join(__dirname, '..', 'functions', filename), 'utf8');
}

// 将 Node-RED function 节点代码包装为可调用函数
// Node-RED function 节点以 msg 为输入、以 return msg 为输出，
// 使用 new Function('msg', code) 将其包装为 function(msg) { ... }
function loadNodeRedFunction(filename) {
    const code = loadFunctionCode(filename);
    return new Function('msg', code);
}

// 从 Node-RED function 文件中提取指定名称的函数定义
// 适用于文件内定义了独立命名函数（例如 calculateProgressiveOverload）的情况
// 会自动剥离末尾的 Node-RED 执行代码（从 "var result" 开始的部分）
function extractNamedFunction(filename, funcName) {
    const code = loadFunctionCode(filename);
    const funcStart = code.indexOf('function ' + funcName);
    if (funcStart === -1) {
        throw new Error('在 ' + filename + ' 中未找到函数: ' + funcName);
    }
    const funcCode = code.substring(funcStart);
    // 移除末尾的 Node-RED 执行代码（从 "\nvar result" 开始到文件末尾）
    const execMarker = funcCode.indexOf('\nvar result');
    const funcDef = execMarker > 0 ? funcCode.substring(0, execMarker).trim() : funcCode;
    // 在 vm 沙箱中执行函数声明，以便获取函数引用
    const sandbox = {};
    vm.runInNewContext(funcDef, sandbox);
    if (typeof sandbox[funcName] !== 'function') {
        throw new Error('无法提取函数: ' + funcName);
    }
    return sandbox[funcName];
}

// 重置 helper（停止 Node-RED 测试服务）
function reset() {
    helper.stopServer(function () {});
}

module.exports = {
    helper: helper,
    loadFunctionCode: loadFunctionCode,
    loadNodeRedFunction: loadNodeRedFunction,
    extractNamedFunction: extractNamedFunction,
    reset: reset
};
