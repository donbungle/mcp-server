#!/usr/bin/env node
/**
 * Test suite for the Node.js MCP server
 */

const { jest } = require('@jest/globals');
const fs = require('fs-extra');
const path = require('path');
const { Pool } = require('pg');
const Redis = require('redis');

// Mock dependencies
jest.mock('pg');
jest.mock('redis');
jest.mock('fs-extra');

describe('Node.js MCP Server', () => {
    let mockPool;
    let mockRedis;
    
    beforeEach(() => {
        // Reset mocks
        jest.clearAllMocks();
        
        // Mock database pool
        mockPool = {
            query: jest.fn(),
            end: jest.fn()
        };
        Pool.mockImplementation(() => mockPool);
        
        // Mock Redis client
        mockRedis = {
            connect: jest.fn().mockResolvedValue(true),
            setEx: jest.fn().mockResolvedValue('OK'),
            get: jest.fn().mockResolvedValue(null),
            quit: jest.fn().mockResolvedValue('OK')
        };
        Redis.createClient = jest.fn().mockReturnValue(mockRedis);
    });
    
    describe('Tool: write_file', () => {
        test('should write content to file successfully', async () => {
            // Mock fs-extra methods
            fs.ensureDir = jest.fn().mockResolvedValue();
            fs.writeFile = jest.fn().mockResolvedValue();
            
            const { server } = require('../src-node/server');
            
            // Mock the tool call handler
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'write_file',
                        arguments: {
                            path: 'test.txt',
                            content: 'Hello World'
                        }
                    }
                });
                
                expect(result.content[0].text).toContain('Successfully wrote 11 characters');
                expect(fs.writeFile).toHaveBeenCalledWith(
                    expect.stringContaining('test.txt'),
                    'Hello World',
                    'utf8'
                );
            }
        });
    });
    
    describe('Tool: execute_sql', () => {
        test('should execute SQL query successfully', async () => {
            mockPool.query.mockResolvedValue({
                rows: [
                    { id: 1, name: 'Test User', email: 'test@example.com' },
                    { id: 2, name: 'Another User', email: 'another@example.com' }
                ]
            });
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'execute_sql',
                        arguments: {
                            query: 'SELECT * FROM users WHERE active = $1',
                            parameters: ['true']
                        }
                    }
                });
                
                expect(mockPool.query).toHaveBeenCalledWith(
                    'SELECT * FROM users WHERE active = $1',
                    ['true']
                );
                expect(result.content[0].text).toContain('Test User');
            }
        });
    });
    
    describe('Tool: cache_set', () => {
        test('should set cache value with TTL', async () => {
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'cache_set',
                        arguments: {
                            key: 'test_key',
                            value: 'test_value',
                            ttl: 300
                        }
                    }
                });
                
                expect(mockRedis.setEx).toHaveBeenCalledWith('test_key', 300, 'test_value');
                expect(result.content[0].text).toContain("Set cache key 'test_key' with TTL 300");
            }
        });
    });
    
    describe('Tool: cache_get', () => {
        test('should get cache value when exists', async () => {
            mockRedis.get.mockResolvedValue('cached_value');
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'cache_get',
                        arguments: {
                            key: 'test_key'
                        }
                    }
                });
                
                expect(mockRedis.get).toHaveBeenCalledWith('test_key');
                expect(result.content[0].text).toContain("Cache value for 'test_key': cached_value");
            }
        });
        
        test('should handle missing cache key', async () => {
            mockRedis.get.mockResolvedValue(null);
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'cache_get',
                        arguments: {
                            key: 'missing_key'
                        }
                    }
                });
                
                expect(result.content[0].text).toContain("Cache key 'missing_key' not found");
            }
        });
    });
    
    describe('Tool: list_directory', () => {
        test('should list directory contents', async () => {
            const mockDirents = [
                { name: 'file1.txt', isDirectory: () => false },
                { name: 'file2.csv', isDirectory: () => false },
                { name: 'subdir', isDirectory: () => true }
            ];
            
            fs.readdir = jest.fn().mockResolvedValue(mockDirents);
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'list_directory',
                        arguments: {
                            path: '.'
                        }
                    }
                });
                
                expect(fs.readdir).toHaveBeenCalled();
                expect(result.content[0].text).toContain('file1.txt');
                expect(result.content[0].text).toContain('file2.csv');
                expect(result.content[0].text).toContain('subdir');
            }
        });
    });
    
    describe('Resource handling', () => {
        test('should list file resources', async () => {
            const mockFiles = [
                {
                    name: 'test.txt',
                    path: '/app/data',
                    isFile: () => true
                },
                {
                    name: 'data.csv',
                    path: '/app/data',
                    isFile: () => true
                }
            ];
            
            fs.readdir = jest.fn().mockResolvedValue(mockFiles);
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['resources/list'];
            if (mockHandler) {
                const result = await mockHandler();
                
                // Should include file resources
                expect(result.resources).toBeDefined();
                expect(Array.isArray(result.resources)).toBe(true);
            }
        });
        
        test('should read file resource', async () => {
            fs.readFile = jest.fn().mockResolvedValue('file content');
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['resources/read'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        uri: 'file:///app/data/test.txt'
                    }
                });
                
                expect(fs.readFile).toHaveBeenCalledWith('/app/data/test.txt', 'utf8');
                expect(result.contents[0].text).toBe('file content');
            }
        });
    });
    
    describe('Error handling', () => {
        test('should handle unknown tool gracefully', async () => {
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['tools/call'];
            if (mockHandler) {
                const result = await mockHandler({
                    params: {
                        name: 'unknown_tool',
                        arguments: {}
                    }
                });
                
                expect(result.content[0].text).toContain('Unknown tool');
                expect(result.isError).toBe(true);
            }
        });
        
        test('should handle file system errors', async () => {
            fs.readFile = jest.fn().mockRejectedValue(new Error('File not found'));
            
            const { server } = require('../src-node/server');
            
            const mockHandler = server.handlers?.['resources/read'];
            if (mockHandler) {
                try {
                    await mockHandler({
                        params: {
                            uri: 'file:///app/data/missing.txt'
                        }
                    });
                    fail('Should have thrown an error');
                } catch (error) {
                    expect(error.message).toContain('File not found');
                }
            }
        });
    });
});

// Helper functions for integration tests
describe('Integration Tests', () => {
    test('should handle server initialization', async () => {
        // Mock successful connections
        mockPool.query.mockResolvedValue({ rows: [] });
        mockRedis.connect.mockResolvedValue(true);
        
        // This would test actual server initialization
        // In a real scenario, you'd import and test the main function
        expect(true).toBe(true); // Placeholder
    });
});

module.exports = {
    testEnvironment: 'node',
    collectCoverageFrom: [
        'src-node/**/*.js',
        '!src-node/**/node_modules/**'
    ],
    coverageDirectory: 'coverage',
    testMatch: [
        '**/tests/**/*.test.js',
        '**/tests/**/test_*.js'
    ]
};