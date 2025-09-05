#!/usr/bin/env python3
import asyncio
import json
import os
import sys
import logging
from typing import Any, Dict, List, Optional
import debugpy
import aiofiles
import psycopg2
import redis.asyncio as redis
import pandas as pd
from pathlib import Path

from mcp.server.models import InitializationOptions
from mcp.server import NotificationOptions, Server
from mcp.types import Resource, Tool, TextContent, ImageContent, EmbeddedResource
import mcp.types as types

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Enable debugging if DEBUG env var is set
if os.getenv("DEBUG"):
    debugpy.listen(("0.0.0.0", 5678))
    logger.info("Debug server started on port 5678")

# Configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://mcp_user:mcp_password@postgres:5432/mcp_dev")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
DATA_DIR = Path("/app/data")

# Initialize MCP server
server = Server("mcp-dev-server")

# Global connections
db_pool = None
redis_client = None

async def init_connections():
    """Initialize database and Redis connections"""
    global db_pool, redis_client
    
    try:
        # Initialize Redis
        redis_client = redis.from_url(REDIS_URL, decode_responses=True)
        await redis_client.ping()
        logger.info("Redis connection established")
        
        # Database connection will be handled per-operation
        logger.info("Database connection configured")
        
    except Exception as e:
        logger.error(f"Failed to initialize connections: {e}")
        raise

@server.list_resources()
async def handle_list_resources() -> list[Resource]:
    """List available resources"""
    resources = []
    
    # Add data directory files
    if DATA_DIR.exists():
        for file_path in DATA_DIR.rglob("*"):
            if file_path.is_file():
                resources.append(Resource(
                    uri=f"file://{file_path}",
                    name=file_path.name,
                    description=f"File: {file_path.relative_to(DATA_DIR)}",
                    mimeType="text/plain" if file_path.suffix in [".txt", ".csv", ".json"] else "application/octet-stream"
                ))
    
    # Add database tables
    try:
        import psycopg2
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("""
            SELECT table_name, table_type 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        """)
        
        for table_name, table_type in cur.fetchall():
            resources.append(Resource(
                uri=f"db://table/{table_name}",
                name=table_name,
                description=f"Database {table_type.lower()}: {table_name}",
                mimeType="application/x-sql"
            ))
        
        conn.close()
    except Exception as e:
        logger.warning(f"Could not list database tables: {e}")
    
    return resources

@server.read_resource()
async def handle_read_resource(uri: str) -> str:
    """Read a resource by URI"""
    if uri.startswith("file://"):
        file_path = Path(uri[7:])  # Remove 'file://' prefix
        if not file_path.exists():
            raise ValueError(f"File not found: {file_path}")
        
        async with aiofiles.open(file_path, 'r') as f:
            content = await f.read()
            return content
    
    elif uri.startswith("db://table/"):
        table_name = uri[11:]  # Remove 'db://table/' prefix
        
        import psycopg2
        import psycopg2.extras
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        try:
            cur.execute(f"SELECT * FROM {table_name} LIMIT 100")
            rows = cur.fetchall()
            return json.dumps([dict(row) for row in rows], indent=2, default=str)
        finally:
            conn.close()
    
    else:
        raise ValueError(f"Unsupported URI scheme: {uri}")

@server.list_tools()
async def handle_list_tools() -> list[Tool]:
    """List available tools"""
    return [
        Tool(
            name="write_file",
            description="Write content to a file in the data directory",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Relative path within the data directory"
                    },
                    "content": {
                        "type": "string",
                        "description": "Content to write to the file"
                    }
                },
                "required": ["path", "content"]
            }
        ),
        Tool(
            name="execute_sql",
            description="Execute a SQL query against the PostgreSQL database",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "SQL query to execute"
                    },
                    "parameters": {
                        "type": "array",
                        "description": "Query parameters",
                        "items": {"type": "string"}
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="cache_set",
            description="Set a value in Redis cache",
            inputSchema={
                "type": "object",
                "properties": {
                    "key": {
                        "type": "string",
                        "description": "Cache key"
                    },
                    "value": {
                        "type": "string",
                        "description": "Value to cache"
                    },
                    "ttl": {
                        "type": "integer",
                        "description": "Time to live in seconds (optional)",
                        "default": 3600
                    }
                },
                "required": ["key", "value"]
            }
        ),
        Tool(
            name="cache_get",
            description="Get a value from Redis cache",
            inputSchema={
                "type": "object",
                "properties": {
                    "key": {
                        "type": "string",
                        "description": "Cache key"
                    }
                },
                "required": ["key"]
            }
        ),
        Tool(
            name="list_directory",
            description="List contents of a directory",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Directory path (relative to data directory)",
                        "default": "."
                    }
                }
            }
        ),
        Tool(
            name="analyze_data",
            description="Perform basic analysis on CSV data files",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {
                        "type": "string",
                        "description": "Path to CSV file (relative to data directory)"
                    },
                    "analysis_type": {
                        "type": "string",
                        "enum": ["summary", "head", "info", "describe"],
                        "description": "Type of analysis to perform",
                        "default": "summary"
                    }
                },
                "required": ["file_path"]
            }
        )
    ]

@server.call_tool()
async def handle_call_tool(name: str, arguments: dict[str, Any]) -> list[types.TextContent]:
    """Handle tool calls"""
    
    if name == "write_file":
        path = arguments["path"]
        content = arguments["content"]
        
        file_path = DATA_DIR / path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        async with aiofiles.open(file_path, 'w') as f:
            await f.write(content)
        
        return [types.TextContent(
            type="text",
            text=f"Successfully wrote {len(content)} characters to {path}"
        )]
    
    elif name == "execute_sql":
        query = arguments["query"]
        parameters = arguments.get("parameters", [])
        
        import psycopg2
        import psycopg2.extras
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        try:
            cur.execute(query, parameters)
            
            if cur.description:  # SELECT query
                rows = cur.fetchall()
                result = json.dumps([dict(row) for row in rows], indent=2, default=str)
            else:  # INSERT/UPDATE/DELETE
                conn.commit()
                result = f"Query executed successfully. Rows affected: {cur.rowcount}"
            
            return [types.TextContent(type="text", text=result)]
            
        finally:
            conn.close()
    
    elif name == "cache_set":
        key = arguments["key"]
        value = arguments["value"]
        ttl = arguments.get("ttl", 3600)
        
        await redis_client.setex(key, ttl, value)
        return [types.TextContent(
            type="text",
            text=f"Set cache key '{key}' with TTL {ttl} seconds"
        )]
    
    elif name == "cache_get":
        key = arguments["key"]
        value = await redis_client.get(key)
        
        if value is None:
            return [types.TextContent(type="text", text=f"Cache key '{key}' not found")]
        else:
            return [types.TextContent(type="text", text=f"Cache value for '{key}': {value}")]
    
    elif name == "list_directory":
        path = arguments.get("path", ".")
        dir_path = DATA_DIR / path
        
        if not dir_path.exists():
            return [types.TextContent(type="text", text=f"Directory not found: {path}")]
        
        items = []
        for item in dir_path.iterdir():
            item_type = "directory" if item.is_dir() else "file"
            size = item.stat().st_size if item.is_file() else "-"
            items.append(f"{item_type:9} {size:>10} {item.name}")
        
        result = "\n".join(["Type      Size       Name"] + ["-" * 30] + items)
        return [types.TextContent(type="text", text=result)]
    
    elif name == "analyze_data":
        file_path = arguments["file_path"]
        analysis_type = arguments.get("analysis_type", "summary")
        
        full_path = DATA_DIR / file_path
        if not full_path.exists():
            return [types.TextContent(type="text", text=f"File not found: {file_path}")]
        
        try:
            df = pd.read_csv(full_path)
            
            if analysis_type == "summary":
                result = f"Dataset Summary for {file_path}:\n"
                result += f"Shape: {df.shape}\n"
                result += f"Columns: {list(df.columns)}\n"
                result += f"Data types:\n{df.dtypes}"
            elif analysis_type == "head":
                result = f"First 10 rows of {file_path}:\n{df.head(10).to_string()}"
            elif analysis_type == "info":
                import io
                buffer = io.StringIO()
                df.info(buf=buffer)
                result = f"Dataset info for {file_path}:\n{buffer.getvalue()}"
            elif analysis_type == "describe":
                result = f"Statistical summary for {file_path}:\n{df.describe().to_string()}"
            
            return [types.TextContent(type="text", text=result)]
            
        except Exception as e:
            return [types.TextContent(type="text", text=f"Error analyzing data: {str(e)}")]
    
    else:
        raise ValueError(f"Unknown tool: {name}")

async def main():
    """Main server function"""
    # Initialize connections
    await init_connections()
    
    # Create data directory
    DATA_DIR.mkdir(exist_ok=True)
    
    # Add health check endpoint
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
    
    app = FastAPI()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    @app.get("/health")
    async def health_check():
        return {"status": "healthy", "service": "mcp-dev-server"}
    
    # Start both MCP server and health check server
    import threading
    
    def run_health_server():
        uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")
    
    health_thread = threading.Thread(target=run_health_server, daemon=True)
    health_thread.start()
    
    logger.info("MCP Development Server started")
    logger.info("Health check available at http://localhost:8000/health")
    
    # Run MCP server via stdio
    async with server.stdio() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="mcp-dev-server",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )

if __name__ == "__main__":
    asyncio.run(main())