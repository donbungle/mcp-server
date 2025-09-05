MCP Development Environment - Static Files
===========================================

This directory contains static files served by the Nginx file server.

Features:
- CORS-enabled access
- Directory browsing
- Gzip compression
- Caching headers
- Security headers

You can place any static files here that need to be served over HTTP.

Examples:
- Documentation files
- Sample data files
- Configuration templates
- Test files
- Assets and media

Access these files via:
http://localhost:8080/static/filename

The server also provides:
- Health check: http://localhost:8080/health
- API docs: http://localhost:8080/api/docs
- Data directory: http://localhost:8080/data/
- Root: http://localhost:8080/

All endpoints support CORS for cross-origin access.