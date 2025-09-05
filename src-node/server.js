#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const Redis = require('redis');
const fs = require('fs-extra');
const path = require('path');
const csv = require('csv-parser');
require('dotenv').config();

// Configuration
const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://mcp_user:mcp_password@postgres:5432/mcp_dev';
const REDIS_URL = process.env.REDIS_URL || 'redis://redis:6379';
const DATA_DIR = path.join(__dirname, '../data');

// Initialize connections
let dbPool;
let redisClient;

async function initConnections() {
    try {
        // Initialize PostgreSQL pool
        dbPool = new Pool({ connectionString: DATABASE_URL });
        await dbPool.query('SELECT 1');
        console.log('Database connection established');

        // Initialize Redis
        redisClient = Redis.createClient({ url: REDIS_URL });
        await redisClient.connect();
        console.log('Redis connection established');

        // Ensure data directory exists
        await fs.ensureDir(DATA_DIR);
        console.log('Data directory ready');

    } catch (error) {
        console.error('Failed to initialize connections:', error);
        process.exit(1);
    }
}

// Create MCP server
const server = new Server(
    {
        name: 'mcp-dev-server-node',
        version: '1.0.0',
    },
    {
        capabilities: {
            resources: {},
            tools: {},
        },
    }
);

// List resources handler
server.setRequestHandler('resources/list', async () => {
    const resources = [];

    // Add data directory files
    try {
        const files = await fs.readdir(DATA_DIR, { recursive: true, withFileTypes: true });
        for (const file of files) {
            if (file.isFile()) {
                const filePath = path.join(file.path, file.name);
                const relativePath = path.relative(DATA_DIR, filePath);
                resources.push({
                    uri: `file://${filePath}`,
                    name: file.name,
                    description: `File: ${relativePath}`,
                    mimeType: getFileType(file.name),
                });
            }
        }
    } catch (error) {
        console.warn('Could not list data directory files:', error.message);
    }

    // Add database tables
    try {
        const result = await dbPool.query(`
            SELECT table_name, table_type 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);

        for (const row of result.rows) {
            resources.push({
                uri: `db://table/${row.table_name}`,
                name: row.table_name,
                description: `Database ${row.table_type.toLowerCase()}: ${row.table_name}`,
                mimeType: 'application/x-sql',
            });
        }
    } catch (error) {
        console.warn('Could not list database tables:', error.message);
    }

    return { resources };
});

// Read resource handler
server.setRequestHandler('resources/read', async (request) => {
    const { uri } = request.params;

    if (uri.startsWith('file://')) {
        const filePath = uri.slice(7); // Remove 'file://' prefix
        try {
            const content = await fs.readFile(filePath, 'utf8');
            return {
                contents: [{
                    uri,
                    mimeType: 'text/plain',
                    text: content,
                }],
            };
        } catch (error) {
            throw new Error(`File not found: ${filePath}`);
        }
    } else if (uri.startsWith('db://table/')) {
        const tableName = uri.slice(11); // Remove 'db://table/' prefix
        try {
            const result = await dbPool.query(`SELECT * FROM ${tableName} LIMIT 100`);
            return {
                contents: [{
                    uri,
                    mimeType: 'application/json',
                    text: JSON.stringify(result.rows, null, 2),
                }],
            };
        } catch (error) {
            throw new Error(`Database error: ${error.message}`);
        }
    } else {
        throw new Error(`Unsupported URI scheme: ${uri}`);
    }
});

// List tools handler
server.setRequestHandler('tools/list', async () => {
    return {
        tools: [
            {
                name: 'write_file',
                description: 'Write content to a file in the data directory',
                inputSchema: {
                    type: 'object',
                    properties: {
                        path: {
                            type: 'string',
                            description: 'Relative path within the data directory',
                        },
                        content: {
                            type: 'string',
                            description: 'Content to write to the file',
                        },
                    },
                    required: ['path', 'content'],
                },
            },
            {
                name: 'execute_sql',
                description: 'Execute a SQL query against the PostgreSQL database',
                inputSchema: {
                    type: 'object',
                    properties: {
                        query: {
                            type: 'string',
                            description: 'SQL query to execute',
                        },
                        parameters: {
                            type: 'array',
                            description: 'Query parameters',
                            items: { type: 'string' },
                        },
                    },
                    required: ['query'],
                },
            },
            {
                name: 'cache_set',
                description: 'Set a value in Redis cache',
                inputSchema: {
                    type: 'object',
                    properties: {
                        key: { type: 'string', description: 'Cache key' },
                        value: { type: 'string', description: 'Value to cache' },
                        ttl: { 
                            type: 'integer', 
                            description: 'Time to live in seconds', 
                            default: 3600 
                        },
                    },
                    required: ['key', 'value'],
                },
            },
            {
                name: 'cache_get',
                description: 'Get a value from Redis cache',
                inputSchema: {
                    type: 'object',
                    properties: {
                        key: { type: 'string', description: 'Cache key' },
                    },
                    required: ['key'],
                },
            },
            {
                name: 'list_directory',
                description: 'List contents of a directory',
                inputSchema: {
                    type: 'object',
                    properties: {
                        path: {
                            type: 'string',
                            description: 'Directory path (relative to data directory)',
                            default: '.',
                        },
                    },
                },
            },
            {
                name: 'analyze_csv',
                description: 'Analyze CSV files for basic statistics',
                inputSchema: {
                    type: 'object',
                    properties: {
                        file_path: {
                            type: 'string',
                            description: 'Path to CSV file (relative to data directory)',
                        },
                        limit: {
                            type: 'integer',
                            description: 'Maximum number of rows to analyze',
                            default: 1000,
                        },
                    },
                    required: ['file_path'],
                },
            },
        ],
    };
});

// Tool call handler
server.setRequestHandler('tools/call', async (request) => {
    const { name, arguments: args } = request.params;

    try {
        switch (name) {
            case 'write_file': {
                const { path: filePath, content } = args;
                const fullPath = path.join(DATA_DIR, filePath);
                
                await fs.ensureDir(path.dirname(fullPath));
                await fs.writeFile(fullPath, content, 'utf8');
                
                return {
                    content: [{
                        type: 'text',
                        text: `Successfully wrote ${content.length} characters to ${filePath}`,
                    }],
                };
            }

            case 'execute_sql': {
                const { query, parameters = [] } = args;
                const result = await dbPool.query(query, parameters);
                
                if (result.rows) {
                    return {
                        content: [{
                            type: 'text',
                            text: JSON.stringify(result.rows, null, 2),
                        }],
                    };
                } else {
                    return {
                        content: [{
                            type: 'text',
                            text: `Query executed successfully. Rows affected: ${result.rowCount}`,
                        }],
                    };
                }
            }

            case 'cache_set': {
                const { key, value, ttl = 3600 } = args;
                await redisClient.setEx(key, ttl, value);
                
                return {
                    content: [{
                        type: 'text',
                        text: `Set cache key '${key}' with TTL ${ttl} seconds`,
                    }],
                };
            }

            case 'cache_get': {
                const { key } = args;
                const value = await redisClient.get(key);
                
                return {
                    content: [{
                        type: 'text',
                        text: value ? `Cache value for '${key}': ${value}` : `Cache key '${key}' not found`,
                    }],
                };
            }

            case 'list_directory': {
                const { path: dirPath = '.' } = args;
                const fullPath = path.join(DATA_DIR, dirPath);
                
                try {
                    const items = await fs.readdir(fullPath, { withFileTypes: true });
                    const itemList = items.map(item => {
                        const type = item.isDirectory() ? 'directory' : 'file';
                        return `${type.padEnd(9)} ${item.name}`;
                    });
                    
                    const result = ['Type      Name', '-'.repeat(30), ...itemList].join('\n');
                    
                    return {
                        content: [{
                            type: 'text',
                            text: result,
                        }],
                    };
                } catch (error) {
                    return {
                        content: [{
                            type: 'text',
                            text: `Directory not found: ${dirPath}`,
                        }],
                    };
                }
            }

            case 'analyze_csv': {
                const { file_path, limit = 1000 } = args;
                const fullPath = path.join(DATA_DIR, file_path);
                
                try {
                    const rows = [];
                    
                    return new Promise((resolve, reject) => {
                        fs.createReadStream(fullPath)
                            .pipe(csv())
                            .on('data', (data) => {
                                if (rows.length < limit) {
                                    rows.push(data);
                                }
                            })
                            .on('end', () => {
                                const columns = Object.keys(rows[0] || {});
                                const analysis = {
                                    file: file_path,
                                    totalRows: rows.length,
                                    columns: columns.length,
                                    columnNames: columns,
                                    sample: rows.slice(0, 5),
                                };
                                
                                resolve({
                                    content: [{
                                        type: 'text',
                                        text: `CSV Analysis:\n${JSON.stringify(analysis, null, 2)}`,
                                    }],
                                });
                            })
                            .on('error', (error) => {
                                reject(new Error(`Error analyzing CSV: ${error.message}`));
                            });
                    });
                } catch (error) {
                    return {
                        content: [{
                            type: 'text',
                            text: `Error analyzing CSV: ${error.message}`,
                        }],
                    };
                }
            }

            default:
                throw new Error(`Unknown tool: ${name}`);
        }
    } catch (error) {
        return {
            content: [{
                type: 'text',
                text: `Error: ${error.message}`,
            }],
            isError: true,
        };
    }
});

// Helper function to determine file type
function getFileType(filename) {
    const ext = path.extname(filename).toLowerCase();
    const types = {
        '.txt': 'text/plain',
        '.json': 'application/json',
        '.csv': 'text/csv',
        '.xml': 'application/xml',
        '.html': 'text/html',
        '.md': 'text/markdown',
    };
    return types[ext] || 'application/octet-stream';
}

// Health check server
function startHealthServer() {
    const app = express();
    app.use(cors());

    app.get('/health', (req, res) => {
        res.json({ 
            status: 'healthy', 
            service: 'mcp-dev-server-node',
            timestamp: new Date().toISOString(),
        });
    });

    const port = process.env.PORT || 3000;
    app.listen(port, '0.0.0.0', () => {
        console.log(`Health server running on port ${port}`);
    });
}

// Main function
async function main() {
    try {
        await initConnections();
        
        // Start health check server
        startHealthServer();
        
        console.log('Node.js MCP Development Server started');
        console.log('Health check available at http://localhost:3000/health');
        
        // Create transport and run server
        const transport = new StdioServerTransport();
        await server.connect(transport);
        
        console.log('MCP Server running on stdio transport');
        
    } catch (error) {
        console.error('Server startup failed:', error);
        process.exit(1);
    }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
    console.log('\nShutting down gracefully...');
    if (redisClient) await redisClient.quit();
    if (dbPool) await dbPool.end();
    process.exit(0);
});

// Start the server
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { server };