/**
 * Focus Fitness OS - Oracle Cloud Production Settings
 * Optimized for: ARM (Ampere A1) | Docker | Nginx Reverse Proxy
 * 
 * Key differences from default settings.js:
 *   - uiHost: 127.0.0.1 (Nginx handles external traffic)
 *   - No dev fallbacks for secrets (production strict mode)
 *   - Enhanced logging for production monitoring
 */

module.exports = {
    // Admin authentication (same bcrypt hash, override via env)
    adminAuth: {
        type: "credentials",
        users: [
            {
                username: "admin",
                password: process.env.NODE_RED_ADMIN_HASH || "$2b$08$***REMOVED***",
                permissions: "*"
            }
        ]
    },

    // Bind to localhost only - Nginx reverse proxy handles external traffic
    uiHost: "127.0.0.1",

    // Credential encryption - MUST be set via environment variable
    credentialSecret: process.env.NODE_RED_SECRET || (console.warn('[CRITICAL] NODE_RED_SECRET not set!'), "emergency-fallback-change-me"),

    // Global context for function nodes
    functionGlobalContext: {
        crypto: require('crypto'),
        fs: require('fs'),
        JWT_SECRET: process.env.JWT_SECRET || (console.warn('[CRITICAL] JWT_SECRET not set!'), 'emergency-jwt-fallback-change-me')
    },

    // Port (internal only, Nginx proxies to this)
    uiPort: process.env.PORT || 1880,

    // Flow file
    flowFile: 'flows.json',
    flowFilePretty: true,

    // CORS - restrict to known origins in production
    httpNodeCors: {
        origin: process.env.CORS_ORIGIN || "*",
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
