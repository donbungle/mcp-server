# MCP Server Docker Development Environment

I'll create a comprehensive Docker environment for local MCP server development with hot reloading, database integration, and sample implementations.I've created a comprehensive Docker development environment for MCP server development. This setup provides everything you need to build, test, and debug MCP servers locally.

## 🎯 **What's Included**

**Core Services:**
- **Python MCP Server** (Port 8000) - Full-featured implementation with debugging
- **Node.js MCP Server** (Port 3000) - Alternative implementation 
- **PostgreSQL** (Port 5432) - Database with sample data
- **Redis** (Port 6379) - Caching layer
- **Nginx File Server** (Port 8080) - Static file serving with CORS

**Development Features:**
- Hot reloading for both Python and Node.js
- Built-in debugger support (Python: 5678, Node.js: 9229)
- Comprehensive logging and monitoring
- Pre-configured testing frameworks
- Sample data and schemas
- Code quality tools (linting, formatting, type checking)

## 🚀 **Quick Start**

1. **Setup the environment:**
```bash
# Create directory and download files
mkdir mcp-dev-environment && cd mcp-dev-environment

# Make the setup script executable and run it
chmod +x setup.sh
./setup.sh
```

2. **Verify everything is working:**
```bash
# Check service status
docker-compose ps

# Test endpoints
curl http://localhost:8080/health  # File server
curl http://localhost:8000/health  # Python MCP server  
curl http://localhost:3000/health  # Node.js MCP server
```

3. **Start developing:**
```bash
# Edit the Python MCP server
vim src/main.py

# View logs in real-time
docker-compose logs -f mcp-server

# Run tests
docker-compose exec mcp-server python -m pytest
```

## 🔧 **Key Features of the MCP Servers**

**Available Tools:**
- `write_file` - Write content to files
- `execute_sql` - Run database queries  
- `cache_set/get` - Redis cache operations
- `list_directory` - Browse file system
- `analyze_data` - Basic data analysis on CSV files

**Resources:**
- File system access to `/data` directory
- Database table schemas and sample data
- Configuration files and documentation

**Sample Usage:**
```python
# The Python server provides tools for:
await mcp_server.call_tool("write_file", {
    "path": "analysis.txt", 
    "content": "Sample analysis results"
})

await mcp_server.call_tool("execute_sql", {
    "query": "SELECT * FROM users WHERE department = $1",
    "parameters": ["Engineering"] 
})
```

## 🐛 **Debugging Setup**

**Python (VSCode):**
```json
{
  "name": "Python: Remote Attach",
  "type": "python", 
  "request": "attach",
  "connect": {"host": "localhost", "port": 5678},
  "pathMappings": [
    {"localRoot": "${workspaceFolder}/src", "remoteRoot": "/app/src"}
  ]
}
```

**Node.js (Chrome DevTools):**
- Open `chrome://inspect`
- Connect to `localhost:9229`

## 📊 **Monitoring & Logs**

```bash
# View all service logs
docker-compose logs -f

# Monitor specific service
docker-compose logs -f mcp-server

# Check resource usage
docker stats

# Database operations
docker-compose exec postgres psql -U mcp_user -d mcp_dev

# Redis operations  
docker-compose exec redis redis-cli
```

## 🛠️ **Development Workflow**

The environment supports both transport methods:
- **stdio** (default) - For direct MCP client integration
- **HTTP/WebSocket** - For web-based development and testing

You can easily switch between implementations or run both simultaneously for comparison and testing.

This environment gives you a complete MCP development platform with real databases, caching, file systems, and debugging tools - perfect for building and testing production-ready MCP servers!