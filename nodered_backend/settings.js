/**
 * Focus Fitness OS - Node-RED Security-Hardened Configuration
 *
 * Security hardening (Cycle 7A):
 *   - uiHost: 127.0.0.1 ONLY (editor not exposed to public)
 *   - credentialSecret: fail-fast if NODE_RED_SECRET not set (no dev fallback)
 *   - JWT_SECRET: fail-fast if not set (no dev fallback)
 *   - CORS: restricted to known origins (not "*")
 *   - No default passwords in comments or source code
 *   - Admin password hash loaded from environment variable only
 *
 * JWT Authentication Flow (HMAC-SHA256):
 *   1. POST /api/v1/auth/login   verify password (scrypt) -> issue access_token(1h) + refresh_token(7d)
 *   2. POST /api/v1/auth/refresh carry refresh_token -> issue new access_token
 *   3. POST /api/v1/auth/verify  verify access_token signature and expiry
 *
 * Network boundary:
 *   Public (via Cloudflare Tunnel): /api/v1/*, /health, /ready, /metrics
 *   Private (127.0.0.1 only):      Node-RED Editor, /admin, WebSocket
 */

// Fail-fast: require environment variables, never fall back to insecure defaults
function requireEnv(name) {
    var value = process.env[name];
    if (!value) {
        throw new Error(
            'FATAL: Missing required environment variable: ' + name +
            '. Set it in .env.local (local dev) or deployment environment (production).'
        );
    }
    return value;
}

module.exports = {
    // Admin authentication: only authenticated users can access Node-RED editor
    // Password hash MUST be provided via NODE_RED_ADMIN_HASH environment variable (bcrypt format)
    // Generate hash: node -e "console.log(require('bcryptjs').hashSync('YOUR_PASSWORD', 8))"
    adminAuth: {
        type: "credentials",
        users: [
            {
                username: "admin",
                password: requireEnv("NODE_RED_ADMIN_HASH"),
                permissions: "*"
            }
        ]
    },

    // Bind to localhost ONLY: Node-RED editor is not directly exposed to public
    // Cloudflare Tunnel proxies API traffic to 127.0.0.1:1880
    uiHost: "127.0.0.1",

    // HTTP node authentication: JWT auth implemented in flows (not httpNodeAuth)
    // /api/v1/auth/* endpoints are public (login, refresh, verify)
    // Other /api/v1/* endpoints validate Authorization: Bearer <access_token> in flow

    // Credential encryption secret: fail-fast if not set (no insecure fallback)
    credentialSecret: requireEnv("NODE_RED_SECRET"),

    // Function node global context modules
    // crypto: JWT sign/verify (HMAC-SHA256), refresh_token generation, scrypt password hashing
    // fs: Refresh Token persistence to filesystem
    // JWT_SECRET: injected via environment variable, used by auth flow function nodes
    functionGlobalContext: {
        crypto: require('crypto'),
        fs: require('fs'),
        JWT_SECRET: requireEnv("JWT_SECRET")
    },

    // Default HTTP listen port
    uiPort: process.env.PORT || 1880,

    // Flow file location
    flowFile: 'flows.json',
    flowFilePretty: true,

    // CORS: restricted to known origins (security hardening)
    // Allows GitHub Pages (production) and localhost (development)
    // For custom origins, set CORS_ALLOWED_ORIGINS env var (comma-separated)
    httpNodeCors: {
        origin: process.env.CORS_ALLOWED_ORIGINS || "https://3579828593.github.io,http://127.0.0.1:1880,http://localhost:1880",
        methods: "GET,POST,PUT,DELETE,OPTIONS",
        headers: "Origin,X-Requested-With,Content-Type,Accept,Authorization"
    },

    // Disable unused features to reduce attack surface
    httpStatic: false,

    // Logging configuration
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    }
};
