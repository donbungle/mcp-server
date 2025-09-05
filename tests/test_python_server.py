#!/usr/bin/env python3
"""
Test suite for the Python MCP server
"""
import pytest
import asyncio
import json
import tempfile
import os
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

# Import the server modules
import sys
sys.path.append('/app/src')

@pytest.fixture
def mock_db_pool():
    """Mock database pool for testing"""
    pool = MagicMock()
    return pool

@pytest.fixture
def mock_redis_client():
    """Mock Redis client for testing"""
    client = AsyncMock()
    client.ping.return_value = True
    client.get.return_value = None
    client.setex.return_value = True
    return client

@pytest.fixture
def temp_data_dir():
    """Create temporary data directory for testing"""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)

class TestMCPServer:
    """Test cases for MCP server functionality"""
    
    @pytest.mark.asyncio
    async def test_write_file_tool(self, temp_data_dir):
        """Test the write_file tool"""
        # Mock the DATA_DIR
        with patch('src.main.DATA_DIR', temp_data_dir):
            from src.main import handle_call_tool
            
            # Test writing a file
            result = await handle_call_tool("write_file", {
                "path": "test.txt",
                "content": "Hello, MCP!"
            })
            
            # Check that the result is correct
            assert len(result) == 1
            assert "Successfully wrote 11 characters" in result[0].text
            
            # Check that the file was created
            test_file = temp_data_dir / "test.txt"
            assert test_file.exists()
            assert test_file.read_text() == "Hello, MCP!"
    
    @pytest.mark.asyncio
    async def test_list_directory_tool(self, temp_data_dir):
        """Test the list_directory tool"""
        # Create some test files
        (temp_data_dir / "file1.txt").write_text("content1")
        (temp_data_dir / "file2.txt").write_text("content2")
        (temp_data_dir / "subdir").mkdir()
        
        with patch('src.main.DATA_DIR', temp_data_dir):
            from src.main import handle_call_tool
            
            result = await handle_call_tool("list_directory", {"path": "."})
            
            assert len(result) == 1
            content = result[0].text
            assert "file1.txt" in content
            assert "file2.txt" in content
            assert "subdir" in content
    
    @pytest.mark.asyncio
    async def test_cache_operations(self, mock_redis_client):
        """Test Redis cache operations"""
        with patch('src.main.redis_client', mock_redis_client):
            from src.main import handle_call_tool
            
            # Test cache set
            result = await handle_call_tool("cache_set", {
                "key": "test_key",
                "value": "test_value",
                "ttl": 60
            })
            
            assert len(result) == 1
            assert "Set cache key 'test_key' with TTL 60" in result[0].text
            mock_redis_client.setex.assert_called_once_with("test_key", 60, "test_value")
            
            # Test cache get (not found)
            mock_redis_client.get.return_value = None
            result = await handle_call_tool("cache_get", {"key": "test_key"})
            
            assert len(result) == 1
            assert "Cache key 'test_key' not found" in result[0].text
            
            # Test cache get (found)
            mock_redis_client.get.return_value = "test_value"
            result = await handle_call_tool("cache_get", {"key": "test_key"})
            
            assert len(result) == 1
            assert "Cache value for 'test_key': test_value" in result[0].text
    
    @pytest.mark.asyncio
    async def test_analyze_data_tool(self, temp_data_dir):
        """Test the analyze_data tool with CSV files"""
        # Create a test CSV file
        csv_content = """name,age,department
John,30,Engineering
Jane,25,Marketing
Bob,35,Sales"""
        
        csv_file = temp_data_dir / "test.csv"
        csv_file.write_text(csv_content)
        
        with patch('src.main.DATA_DIR', temp_data_dir):
            from src.main import handle_call_tool
            
            result = await handle_call_tool("analyze_data", {
                "file_path": "test.csv",
                "analysis_type": "summary"
            })
            
            assert len(result) == 1
            content = result[0].text
            assert "Dataset Summary" in content
            assert "Shape: (3, 3)" in content
            assert "name" in content
            assert "age" in content
            assert "department" in content
    
    @pytest.mark.asyncio
    async def test_unknown_tool_error(self):
        """Test that unknown tools raise appropriate errors"""
        from src.main import handle_call_tool
        
        with pytest.raises(ValueError, match="Unknown tool: nonexistent_tool"):
            await handle_call_tool("nonexistent_tool", {})

class TestResourceHandling:
    """Test cases for resource handling"""
    
    @pytest.mark.asyncio
    async def test_list_resources(self, temp_data_dir):
        """Test listing resources"""
        # Create test files
        (temp_data_dir / "test1.txt").write_text("content1")
        (temp_data_dir / "test2.csv").write_text("col1,col2\nval1,val2")
        
        with patch('src.main.DATA_DIR', temp_data_dir):
            from src.main import handle_list_resources
            
            resources = await handle_list_resources()
            
            # Should find the files we created
            file_resources = [r for r in resources if r.uri.startswith("file://")]
            assert len(file_resources) >= 2
            
            # Check file URIs are correct
            uris = [r.uri for r in file_resources]
            assert any("test1.txt" in uri for uri in uris)
            assert any("test2.csv" in uri for uri in uris)
    
    @pytest.mark.asyncio
    async def test_read_file_resource(self, temp_data_dir):
        """Test reading file resources"""
        # Create a test file
        test_file = temp_data_dir / "test.txt"
        test_content = "This is test content"
        test_file.write_text(test_content)
        
        from src.main import handle_read_resource
        
        content = await handle_read_resource(f"file://{test_file}")
        assert content == test_content

if __name__ == "__main__":
    pytest.main([__file__, "-v"])