#!/bin/bash

# MCP Development Environment Setup Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker and Docker Compose
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        echo "Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose is installed"
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker daemon is running"
}

# Function to create necessary directories
create_directories() {
    print_header "Creating Directories"
    
    directories=("data" "static" "logs" "tests")
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Created directory: $dir"
        else
            print_info "Directory already exists: $dir"
        fi
    done
}

# Function to set up environment file
setup_environment() {
    print_header "Setting up Environment"
    
    if [ ! -f ".env" ]; then
        print_success ".env file already exists with comprehensive configuration"
    else
        print_info ".env file found with custom configuration"
        
        # Validate essential environment variables
        if ! grep -q "POSTGRES_PASSWORD" .env; then
            print_warning ".env file missing POSTGRES_PASSWORD, adding default"
            echo "POSTGRES_PASSWORD=mcp_password" >> .env
        fi
        
        if ! grep -q "DATABASE_URL" .env; then
            print_warning ".env file missing DATABASE_URL, adding default"
            echo "DATABASE_URL=postgresql://mcp_user:mcp_password@postgres:5432/mcp_dev" >> .env
        fi
        
        if ! grep -q "REDIS_URL" .env; then
            print_warning ".env file missing REDIS_URL, adding default"
            echo "REDIS_URL=redis://redis:6379" >> .env
        fi
    fi
    
    # Load environment variables for port checking
    if [ -f ".env" ]; then
        export $(grep -v '^#' .env | xargs)
    fi
}

# Function to build Docker images
build_images() {
    print_header "Building Docker Images"
    
    print_info "Building Python MCP server image..."
    if docker-compose build mcp-server; then
        print_success "Python MCP server image built successfully"
    else
        print_error "Failed to build Python MCP server image"
        exit 1
    fi
    
    print_info "Building Node.js MCP server image..."
    if docker-compose build mcp-server-node; then
        print_success "Node.js MCP server image built successfully"
    else
        print_error "Failed to build Node.js MCP server image"
        exit 1
    fi
}

# Function to start services
start_services() {
    print_header "Starting Services"
    
    print_info "Starting all services..."
    if docker-compose up -d; then
        print_success "All services started successfully"
    else
        print_error "Failed to start services"
        exit 1
    fi
    
    # Wait for services to be ready
    print_info "Waiting for services to be ready..."
    sleep 10
}

# Function to check port conflicts
check_ports() {
    print_header "Checking Port Availability"
    
    # Default ports if not set in .env
    PYTHON_SERVER_PORT=${PYTHON_SERVER_PORT:-8000}
    NODE_SERVER_PORT=${NODE_SERVER_PORT:-3000}
    POSTGRES_PORT=${POSTGRES_PORT:-5432}
    REDIS_PORT=${REDIS_PORT:-6379}
    NGINX_PORT=${NGINX_PORT:-8080}
    
    ports=(
        "${PYTHON_SERVER_PORT}|Python MCP Server"
        "${NODE_SERVER_PORT}|Node.js MCP Server"
        "${POSTGRES_PORT}|PostgreSQL"
        "${REDIS_PORT}|Redis"
        "${NGINX_PORT}|Nginx File Server"
    )
    
    for port_info in "${ports[@]}"; do
        IFS='|' read -r port service <<< "$port_info"
        if command_exists netstat; then
            if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
                print_warning "Port $port is already in use (needed for $service)"
                print_info "You can change the port in .env file or stop the conflicting service"
            else
                print_success "Port $port is available for $service"
            fi
        elif command_exists ss; then
            if ss -tulpn 2>/dev/null | grep -q ":$port "; then
                print_warning "Port $port is already in use (needed for $service)"
                print_info "You can change the port in .env file or stop the conflicting service"
            else
                print_success "Port $port is available for $service"
            fi
        else
            print_info "Cannot check port $port availability (netstat/ss not found)"
        fi
    done
}

# Function to verify services
verify_services() {
    print_header "Verifying Services"
    
    # Use environment variables for port configuration
    PYTHON_SERVER_PORT=${PYTHON_SERVER_PORT:-8000}
    NODE_SERVER_PORT=${NODE_SERVER_PORT:-3000}
    NGINX_PORT=${NGINX_PORT:-8080}
    POSTGRES_USER=${POSTGRES_USER:-mcp_user}
    
    services=(
        "http://localhost:${NGINX_PORT}/health|Nginx File Server"
        "http://localhost:${PYTHON_SERVER_PORT}/health|Python MCP Server"
        "http://localhost:${NODE_SERVER_PORT}/health|Node.js MCP Server"
    )
    
    for service in "${services[@]}"; do
        IFS='|' read -r url name <<< "$service"
        if curl -f -s "$url" > /dev/null; then
            print_success "$name is healthy"
        else
            print_warning "$name might not be ready yet (this is normal during first startup)"
        fi
    done
    
    # Check database
    if docker-compose exec -T postgres pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; then
        print_success "PostgreSQL is ready"
    else
        print_warning "PostgreSQL might not be ready yet"
    fi
    
    # Check Redis
    if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
        print_success "Redis is ready"
    else
        print_warning "Redis might not be ready yet"
    fi
}

# Function to show useful information
show_info() {
    print_header "MCP Development Environment Ready!"
    
    # Use environment variables for display
    PYTHON_SERVER_PORT=${PYTHON_SERVER_PORT:-8000}
    NODE_SERVER_PORT=${NODE_SERVER_PORT:-3000}
    POSTGRES_PORT=${POSTGRES_PORT:-5432}
    REDIS_PORT=${REDIS_PORT:-6379}
    NGINX_PORT=${NGINX_PORT:-8080}
    PYTHON_DEBUG_PORT=${PYTHON_DEBUG_PORT:-5678}
    NODE_DEBUG_PORT=${NODE_DEBUG_PORT:-9229}
    
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}\n"
    
    echo -e "${BLUE}Available Services:${NC}"
    echo "• Python MCP Server:   http://localhost:${PYTHON_SERVER_PORT}/health"
    echo "• Node.js MCP Server:  http://localhost:${NODE_SERVER_PORT}/health"
    echo "• Nginx File Server:   http://localhost:${NGINX_PORT}"
    echo "• PostgreSQL:          localhost:${POSTGRES_PORT}"
    echo "• Redis:               localhost:${REDIS_PORT}"
    
    echo -e "\n${BLUE}Debug Ports:${NC}"
    echo "• Python Debugger:     localhost:${PYTHON_DEBUG_PORT}"
    echo "• Node.js Debugger:    localhost:${NODE_DEBUG_PORT}"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "• View logs:           docker-compose logs -f"
    echo "• Stop services:       docker-compose down"
    echo "• Restart services:    docker-compose restart"
    echo "• Connect to DB:       docker-compose exec postgres psql -U mcp_user -d mcp_dev"
    echo "• Connect to Redis:    docker-compose exec redis redis-cli"
    echo "• Run Python tests:    docker-compose exec mcp-server python -m pytest"
    
    echo -e "\n${BLUE}File Locations:${NC}"
    echo "• Python source:       ./src/"
    echo "• Node.js source:      ./src-node/"
    echo "• Data files:          ./data/"
    echo "• Static files:        ./static/"
    echo "• Database scripts:    ./db/"
    
    echo -e "\n${YELLOW}Note:${NC} If services are not responding immediately, wait a few moments for full startup."
    echo -e "You can monitor the startup process with: ${BLUE}docker-compose logs -f${NC}"
}

# Function to handle cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Setup failed. Cleaning up..."
        docker-compose down > /dev/null 2>&1 || true
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    print_header "MCP Development Environment Setup"
    
    check_prerequisites
    create_directories
    setup_environment
    check_ports
    build_images
    start_services
    verify_services
    show_info
}

# Parse command line arguments
case "${1:-setup}" in
    setup)
        main
        ;;
    start)
        print_info "Starting MCP Development Environment..."
        docker-compose up -d
        verify_services
        ;;
    stop)
        print_info "Stopping MCP Development Environment..."
        docker-compose down
        print_success "All services stopped"
        ;;
    restart)
        print_info "Restarting MCP Development Environment..."
        docker-compose restart
        verify_services
        ;;
    status)
        print_header "Service Status"
        docker-compose ps
        echo ""
        verify_services
        ;;
    logs)
        docker-compose logs -f
        ;;
    clean)
        print_warning "This will remove all containers, images, and volumes. Are you sure? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Cleaning up MCP Development Environment..."
            docker-compose down -v --rmi all
            print_success "Cleanup complete"
        else
            print_info "Cleanup cancelled"
        fi
        ;;
    help|--help|-h)
        echo "MCP Development Environment Setup Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup     Setup and start the development environment (default)"
        echo "  start     Start the services"
        echo "  stop      Stop the services"
        echo "  restart   Restart the services"
        echo "  status    Show service status"
        echo "  logs      Show service logs"
        echo "  clean     Remove all containers, images, and volumes"
        echo "  help      Show this help message"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Run '$0 help' for available commands"
        exit 1
        ;;
esac