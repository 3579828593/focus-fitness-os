/**
 * Focus Fitness OS - Oracle Cloud Production Settings
 * Optimized for: ARM (Ampere A1) | Docker | Nginx Reverse Proxy
 *
 * Security hardening (Cycle 7A):
 *   - uiHost: 127.0.0.1 (Nginx handles external traffic)
 *   - Fail-fast: no fallback secrets, server exits if env vars missing
 *   - CORS restricted to known origins
 *   - No hardcoded passwords or hashes
 */

function requireEnv(name) {
    var value = process.env[name];
    if (!value) {
        throw new Error('FATAL: Missing required environment variable: ' + name);
    }
    return value;
}

module.exports = {
    // Admin authentication: hash MUST be provided via NODE_RED_ADMIN_HASH env var
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

    // Bind to localhost only - Nginx reverse proxy handles external traffic
    uiHost: "127.0.0.1",

    // Credential encryption - fail-fast if not set
    credentialSecret: requireEnv("NODE_RED_SECRET"),

    // Global context for function nodes
    functionGlobalContext: {
        crypto: require('crypto'),
        fs: require('fs'),
        JWT_SECRET: requireEnv("JWT_SECRET")
    },

    // Port (internal only, Nginx proxies to this)
    uiPort: process.env.PORT || 1880,

    // Flow file
    flowFile: 'flows.json',
    flowFilePretty: true,

    // CORS - restrict to known origins in production
    httpNodeCors: {
        origin: process.env.CORS_ALLOWED_ORIGINS || "https://3579828593.github.io",
        methods: "GET,POST,PUT,DELETE,OPTIONS",
        headers: "Origin,X-Requested-With,Content-Type,Accept,Authorization"
    },

    // Disable unused features
    httpStatic: false,

    // Enhanced logging for production
    logging: {
        console: {
            level: process.env.LOG_LEVEL || "info",
            metrics: false,
            audit: false
        }
    },

    // Editor theme (optional)
    editorTheme: {
        header: {
            title: "Focus Fitness OS"
        }
    }
};
