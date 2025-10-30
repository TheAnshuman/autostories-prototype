#!/bin/bash

# AutoStories Prototype - Automated Installation Script
# This script automates the setup process for the autostories-prototype project

set -e  # Exit on error

# Color codes for output
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
    echo -e "\n${GREEN}================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}================================================${NC}\n"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Node.js version
check_node_version() {
    if command_exists node; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 14 ]; then
            print_success "Node.js $(node -v) is installed"
            return 0
        else
            print_warning "Node.js version is too old. Please upgrade to Node.js 14 or higher"
            return 1
        fi
    else
        print_error "Node.js is not installed"
        return 1
    fi
}

# Function to check if Docker is running
check_docker() {
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            print_success "Docker is installed and running"
            return 0
        else
            print_warning "Docker is installed but not running. Please start Docker Desktop"
            return 1
        fi
    else
        print_warning "Docker is not installed"
        return 1
    fi
}

# Function to install dependencies
install_dependencies() {
    print_header "STEP 1: Installing Dependencies"
    
    # Install root dependencies (if package.json exists)
    if [ -f "package.json" ]; then
        print_info "Installing root dependencies..."
        npm install
        print_success "Root dependencies installed"
    fi
    
    # Install server dependencies
    if [ -d "server" ] && [ -f "server/package.json" ]; then
        print_info "Installing server dependencies..."
        cd server
        npm install
        cd ..
        print_success "Server dependencies installed"
    else
        print_warning "Server directory or package.json not found"
    fi
    
    # Install client dependencies
    if [ -d "client" ] && [ -f "client/package.json" ]; then
        print_info "Installing client dependencies..."
        cd client
        npm install
        cd ..
        print_success "Client dependencies installed"
    else
        print_warning "Client directory or package.json not found"
    fi
}

# Function to setup Docker and Redis
setup_docker_redis() {
    print_header "STEP 2: Setting Up Docker and Redis"
    
    if check_docker; then
        if [ -f "docker-compose.yml" ]; then
            print_info "Starting Docker containers with docker-compose..."
            docker-compose up -d
            print_success "Docker containers started successfully"
            sleep 3  # Wait for Redis to initialize
            
            # Check if Redis is running
            if docker ps | grep -q redis; then
                print_success "Redis is running in Docker"
            else
                print_warning "Redis container may not be running properly"
            fi
        else
            print_warning "docker-compose.yml not found. Attempting to start Redis manually..."
            docker run -d -p 6379:6379 --name autostories-redis redis:alpine
            print_success "Redis container started manually"
        fi
    else
        print_error "Docker is not available. Please install Docker and try again."
        print_info "Download Docker from: https://www.docker.com/products/docker-desktop"
        return 1
    fi
}

# Function to create .env file
setup_environment() {
    print_header "STEP 3: Setting Up Environment Variables"
    
    # Check if .env already exists
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return 0
        fi
    fi
    
    # Copy from .env.example if it exists
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env file from .env.example"
    else
        touch .env
        print_success "Created empty .env file"
    fi
    
    # Prompt for required API keys and secrets
    print_info "Please provide the following API keys and secrets:"
    echo
    
    # OpenAI API Key
    read -p "Enter your OpenAI API Key (required for AI features): " OPENAI_API_KEY
    if [ -n "$OPENAI_API_KEY" ]; then
        if grep -q "OPENAI_API_KEY=" .env; then
            sed -i.bak "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_API_KEY|" .env
        else
            echo "OPENAI_API_KEY=$OPENAI_API_KEY" >> .env
        fi
    fi
    
    # Session Secret
    read -p "Enter a session secret (press Enter to generate random): " SESSION_SECRET
    if [ -z "$SESSION_SECRET" ]; then
        SESSION_SECRET=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
        print_info "Generated random session secret"
    fi
    if grep -q "SESSION_SECRET=" .env; then
        sed -i.bak "s|SESSION_SECRET=.*|SESSION_SECRET=$SESSION_SECRET|" .env
    else
        echo "SESSION_SECRET=$SESSION_SECRET" >> .env
    fi
    
    # Redis URL (default for Docker)
    if ! grep -q "REDIS_URL=" .env; then
        echo "REDIS_URL=redis://localhost:6379" >> .env
        print_success "Added Redis URL to .env"
    fi
    
    # Port configuration
    if ! grep -q "PORT=" .env; then
        echo "PORT=3000" >> .env
    fi
    
    if ! grep -q "CLIENT_PORT=" .env; then
        echo "CLIENT_PORT=5173" >> .env
    fi
    
    # Clean up backup file if created
    rm -f .env.bak
    
    print_success "Environment variables configured"
}

# Function to run post-install checks
post_install_checks() {
    print_header "STEP 4: Running Post-Install Checks"
    
    # Check if .env file exists and has content
    if [ -f ".env" ] && [ -s ".env" ]; then
        print_success ".env file is configured"
    else
        print_warning ".env file is empty or missing"
    fi
    
    # Check if node_modules exist
    if [ -d "node_modules" ] || [ -d "server/node_modules" ] || [ -d "client/node_modules" ]; then
        print_success "Dependencies are installed"
    else
        print_warning "Some dependencies may be missing"
    fi
    
    # Check Docker status
    if check_docker && docker ps | grep -q redis; then
        print_success "Redis is running"
    else
        print_warning "Redis may not be running"
    fi
}

# Function to display next steps
show_next_steps() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}Next steps to run the application:${NC}\n"
    
    echo -e "${BLUE}1. Start the server:${NC}"
    echo -e "   cd server && npm run dev"
    echo
    
    echo -e "${BLUE}2. In a new terminal, start the client:${NC}"
    echo -e "   cd client && npm run dev"
    echo
    
    echo -e "${BLUE}3. Access the application:${NC}"
    echo -e "   Client: http://localhost:5173"
    echo -e "   Server: http://localhost:3000"
    echo
    
    echo -e "${YELLOW}Important Notes:${NC}"
    echo -e "- Make sure Docker is running before starting the server"
    echo -e "- If you encounter any errors, check the .env file configuration"
    echo -e "- Redis must be running for the application to work properly"
    echo
    
    echo -e "${GREEN}Troubleshooting:${NC}"
    echo -e "- Check Redis status: docker ps | grep redis"
    echo -e "- View Redis logs: docker logs autostories-redis"
    echo -e "- Restart Redis: docker-compose restart (or docker restart autostories-redis)"
    echo
    
    print_success "Setup completed successfully! Happy coding!"
}

# Main installation flow
main() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                                                       ║"
    echo "║     AutoStories Prototype - Installation Script      ║"
    echo "║                                                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    print_info "Starting automated installation process...\n"
    
    # Check prerequisites
    print_header "Checking Prerequisites"
    
    if ! check_node_version; then
        print_error "Please install Node.js 14 or higher from https://nodejs.org/"
        exit 1
    fi
    
    if ! command_exists npm; then
        print_error "npm is not installed. Please install Node.js which includes npm"
        exit 1
    fi
    
    print_success "All prerequisites met\n"
    
    # Run installation steps
    install_dependencies || { print_error "Failed to install dependencies"; exit 1; }
    
    setup_docker_redis || print_warning "Docker/Redis setup had issues. You may need to configure manually."
    
    setup_environment || { print_error "Failed to setup environment"; exit 1; }
    
    post_install_checks
    
    show_next_steps
}

# Run main function
main
