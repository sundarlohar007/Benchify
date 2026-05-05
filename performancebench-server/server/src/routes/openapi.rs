use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::Json;

/// GET /api/v1/openapi.json — returns OpenAPI 3.0 specification JSON.
/// Generated manually for now; utoipa derive macros can be added later (D-17).
pub async fn openapi_json() -> impl IntoResponse {
    let spec = serde_json::json!({
        "openapi": "3.0.3",
        "info": {
            "title": "PerformanceBench API",
            "version": "1.0.0",
            "description": "REST API for the PerformanceBench team server — sessions, trends, alerts, devices, tokens, webhooks."
        },
        "servers": [
            { "url": "/api/v1", "description": "API v1" }
        ],
        "paths": {
            "/health": {
                "get": {
                    "summary": "Health check",
                    "responses": {
                        "200": { "description": "Server is healthy" }
                    }
                }
            },
            "/sessions": {
                "get": {
                    "summary": "List sessions (paginated)",
                    "parameters": [
                        { "name": "offset", "in": "query", "schema": { "type": "integer", "default": 0 } },
                        { "name": "limit", "in": "query", "schema": { "type": "integer", "default": 50 } },
                        { "name": "app_name", "in": "query", "schema": { "type": "string" } },
                        { "name": "device_model", "in": "query", "schema": { "type": "string" } },
                        { "name": "project_id", "in": "query", "schema": { "type": "string" } },
                        { "name": "tags", "in": "query", "schema": { "type": "string" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": {
                        "200": { "description": "Paginated session list" }
                    }
                },
                "post": {
                    "summary": "Upload session (multipart)",
                    "security": [{ "bearerAuth": [] }],
                    "responses": {
                        "201": { "description": "Session created" },
                        "409": { "description": "Session already exists" }
                    }
                }
            },
            "/sessions/{id}": {
                "get": {
                    "summary": "Get session detail",
                    "parameters": [
                        { "name": "id", "in": "path", "required": true, "schema": { "type": "string", "format": "uuid" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": {
                        "200": { "description": "Session detail" },
                        "404": { "description": "Not found" }
                    }
                },
                "delete": {
                    "summary": "Delete session",
                    "parameters": [
                        { "name": "id", "in": "path", "required": true, "schema": { "type": "string", "format": "uuid" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": {
                        "200": { "description": "Deleted" }
                    }
                }
            },
            "/trends/fps": {
                "get": {
                    "summary": "FPS trends across sessions",
                    "parameters": [
                        { "name": "start_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "end_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "app_name", "in": "query", "schema": { "type": "string" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": { "200": { "description": "FPS trend data points" } }
                }
            },
            "/trends/cpu": {
                "get": {
                    "summary": "CPU trends across sessions",
                    "parameters": [
                        { "name": "start_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "end_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "app_name", "in": "query", "schema": { "type": "string" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": { "200": { "description": "CPU trend data points" } }
                }
            },
            "/trends/memory": {
                "get": {
                    "summary": "Memory trends across sessions",
                    "parameters": [
                        { "name": "start_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "end_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "app_name", "in": "query", "schema": { "type": "string" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": { "200": { "description": "Memory trend data points" } }
                }
            },
            "/trends/battery": {
                "get": {
                    "summary": "Battery trends across sessions",
                    "parameters": [
                        { "name": "start_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "end_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "app_name", "in": "query", "schema": { "type": "string" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": { "200": { "description": "Battery trend data points" } }
                }
            },
            "/trends/network": {
                "get": {
                    "summary": "Network trends across sessions",
                    "parameters": [
                        { "name": "start_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "end_date", "in": "query", "required": true, "schema": { "type": "string", "format": "date" } },
                        { "name": "app_name", "in": "query", "schema": { "type": "string" } }
                    ],
                    "security": [{ "bearerAuth": [] }],
                    "responses": { "200": { "description": "Network trend data points" } }
                }
            },
            "/lenses": {
                "get": { "summary": "List lenses", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Lenses list" } } },
                "post": { "summary": "Create lens", "security": [{ "bearerAuth": [] }], "responses": { "201": { "description": "Lens created" } } }
            },
            "/lenses/{id}": {
                "get": { "summary": "Get lens detail", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Lens detail" } } },
                "put": { "summary": "Update lens", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Lens updated" } } },
                "delete": { "summary": "Delete lens", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Deleted" } } }
            },
            "/alerts/rules": {
                "get": { "summary": "List alert rules", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Alert rules list" } } },
                "post": { "summary": "Create alert rule", "security": [{ "bearerAuth": [] }], "responses": { "201": { "description": "Alert rule created" } } }
            },
            "/alerts/rules/{id}": {
                "put": { "summary": "Update alert rule", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Updated" } } },
                "delete": { "summary": "Delete alert rule", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Deleted" } } }
            },
            "/alerts/events": {
                "get": { "summary": "List alert events", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Alert events list" } } }
            },
            "/devices": {
                "get": { "summary": "List devices", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Devices list" } } }
            },
            "/devices/{id}": {
                "get": { "summary": "Get device detail", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Device detail" } } }
            },
            "/tokens": {
                "get": { "summary": "List API tokens", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Tokens list" } } },
                "post": { "summary": "Create API token", "security": [{ "bearerAuth": [] }], "responses": { "201": { "description": "Token created" } } }
            },
            "/tokens/{id}": {
                "delete": { "summary": "Revoke API token", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Revoked" } } }
            },
            "/webhooks": {
                "get": { "summary": "List webhooks", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Webhooks list" } } },
                "post": { "summary": "Create webhook", "security": [{ "bearerAuth": [] }], "responses": { "201": { "description": "Webhook created" } } }
            },
            "/webhooks/{id}": {
                "put": { "summary": "Update webhook", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Updated" } } },
                "delete": { "summary": "Delete webhook", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Deleted" } } }
            },
            "/auth/login": {
                "post": { "summary": "Login (email + password)", "responses": { "200": { "description": "JWT set in cookie" } } }
            },
            "/auth/register": {
                "post": { "summary": "Register new user", "responses": { "201": { "description": "User created" } } }
            },
            "/auth/refresh": {
                "post": { "summary": "Refresh JWT", "responses": { "200": { "description": "New JWT" } } }
            },
            "/auth/logout": {
                "post": { "summary": "Logout (clear cookie)", "responses": { "200": { "description": "Logged out" } } }
            }
        },
        "components": {
            "securitySchemes": {
                "bearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT or API Token (pb_ prefix)"
                }
            }
        }
    });

    (StatusCode::OK, Json(spec))
}
