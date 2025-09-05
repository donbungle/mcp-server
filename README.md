# MCP Development Environment

A comprehensive Docker-based development environment for building and testing Model Context Protocol (MCP) servers.

## 🎯 What's Included

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

## 🚀 Quick Start

1. **Setup the environment:**
```bash
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

## 🔧 Key Features of the MCP Servers

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

## 🐛 Debugging Setup

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

## 📊 Monitoring & Logs

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

## 🛠️ Development Workflow

The environment supports both transport methods:
- **stdio** (default) - For direct MCP client integration
- **HTTP/WebSocket** - For web-based development and testing

You can easily switch between implementations or run both simultaneously for comparison and testing.

## 🗂️ Project Structure

```
mcp/
├── src/                    # Python MCP server source
│   └── main.py            # Main Python server implementation
├── src-node/              # Node.js MCP server source
│   └── server.js          # Main Node.js server implementation
├── db/                    # Database initialization scripts
│   ├── init.sql           # Schema and tables
│   └── sample_data.sql    # Sample data
├── data/                  # Data files (mounted to containers)
├── static/                # Static files served by Nginx
├── tests/                 # Test suites
├── .vscode/               # VSCode debug configuration
├── docker-compose.yml     # Service definitions
├── python.Dockerfile      # Python server container
├── node.Dockerfile        # Node.js server container
├── nginx.conf             # Nginx configuration
├── setup.sh               # Setup and management script
└── README.md              # This file
```

## 🔧 Management Commands

The `setup.sh` script provides convenient management:

```bash
./setup.sh setup     # Initial setup and start (default)
./setup.sh start     # Start services
./setup.sh stop      # Stop services  
./setup.sh restart   # Restart services
./setup.sh status    # Show service status
./setup.sh logs      # Show service logs
./setup.sh clean     # Remove everything (with confirmation)
./setup.sh help      # Show help
```

## 🧪 Testing

Both Python and Node.js servers include comprehensive test suites:

```bash
# Run Python tests
docker-compose exec mcp-server python -m pytest tests/ -v

# Run Node.js tests  
docker-compose exec mcp-server-node npm test

# Run tests with coverage
docker-compose exec mcp-server python -m pytest tests/ --cov=src
```

## 🔍 Database Schema

The PostgreSQL database includes several sample tables:
- `users` - User accounts with departments and roles
- `products` - Product catalog with categories and inventory
- `orders` - Order history with status tracking
- `order_items` - Order line items
- `analytics_events` - Event tracking data
- `app_config` - Application configuration

## 📡 API Endpoints

**File Server (Port 8080):**
- `GET /health` - Health check
- `GET /data/` - Browse data directory
- `GET /static/` - Browse static files
- `GET /api/docs` - API documentation

**Python MCP Server (Port 8000):**
- `GET /health` - Health check
- MCP protocol via stdio transport

**Node.js MCP Server (Port 3000):**
- `GET /health` - Health check  
- MCP protocol via stdio transport

## 🚨 Troubleshooting

**Services not starting:**
1. Check Docker is running: `docker info`
2. Check port conflicts: `netstat -tulpn | grep :8000`
3. View startup logs: `docker-compose logs`

**Database connection issues:**
```bash
# Test database connectivity
docker-compose exec postgres pg_isready -U mcp_user

# Connect to database manually
docker-compose exec postgres psql -U mcp_user -d mcp_dev
```

**Redis connection issues:**
```bash
# Test Redis connectivity
docker-compose exec redis redis-cli ping
```

**Debug not working:**
- Ensure debug ports (5678, 9229) are not in use
- Check firewall settings
- Verify VSCode debug configuration matches container setup

## 🤝 Contributing

1. Fork the repository
2. Make changes in your environment
3. Test thoroughly with provided test suites
4. Submit a pull request

## 📄 License

This project is provided as-is for development and testing purposes.

---

This environment gives you a complete MCP development platform with real databases, caching, file systems, and debugging tools - perfect for building and testing production-ready MCP servers!