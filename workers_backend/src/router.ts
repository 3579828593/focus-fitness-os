// src/router.ts
// 轻量 URL 路由器 — 不引入外部依赖 (不使用 Hono/itty-router)。
//
// 功能:
//   - add(method, path, handler): 注册路由, path 支持 ":param" 占位符 (匹配 [^/]+)
//   - match(method, path):        按 (method, path) 匹配, 返回 { handler, params } 或 null
//
// 例: router.add('POST', '/api/v1/proposals/:id/accept', handler)
//     router.match('POST', '/api/v1/proposals/42/accept') -> { handler, params: { id: '42' } }

import type { Handler } from './types';

interface Route {
  method: string;
  pattern: RegExp;
  paramNames: string[];
  handler: Handler;
}

/** 转义正则元字符 (用于 path 中的字面量段) */
function escapeRegExp(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export class Router {
  private routes: Route[] = [];

  /** 注册一条路由 */
  add(method: string, path: string, handler: Handler): void {
    const paramNames: string[] = [];
    // 按 "/" 切分, 逐段处理: ":param" -> 捕获组, 其余转义为字面量
    const segments = path.split('/').map((seg) => {
      if (seg.startsWith(':')) {
        const name = seg.slice(1);
        if (!name) throw new Error(`Invalid param segment in path: ${path}`);
        paramNames.push(name);
        return '([^/]+)';
      }
      return escapeRegExp(seg);
    });
    const pattern = new RegExp(`^${segments.join('/')}$`);
    this.routes.push({
      method: method.toUpperCase(),
      pattern,
      paramNames,
      handler,
    });
  }

  /** 匹配请求, 返回处理器与提取的路径参数 */
  match(method: string, path: string): { handler: Handler; params: Record<string, string> } | null {
    const upperMethod = method.toUpperCase();
    for (const route of this.routes) {
      if (route.method !== upperMethod) continue;
      const m = path.match(route.pattern);
      if (m) {
        const params: Record<string, string> = {};
        route.paramNames.forEach((name, i) => {
          params[name] = decodeURIComponent(m[i + 1]);
        });
        return { handler: route.handler, params };
      }
    }
    return null;
  }

  /** 已注册路由数 (测试/调试用) */
  size(): number {
    return this.routes.length;
  }
}
