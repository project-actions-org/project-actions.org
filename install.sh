#!/bin/bash
#
# Project Actions Installation Script
#
# Usage:
#   curl -fsSL https://project-actions.org/install.sh | bash
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR=".project"
RUNTIME_DIR="${PROJECT_DIR}/.runtime"
COMMANDS_DIR="${PROJECT_DIR}"
RUNNER_SCRIPT="runner.sh"
PROJECT_SCRIPT="project"

# Detect platform
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac

    echo "${os}-${arch}"
}

# Detect the project framework by inspecting marker files
detect_framework() {
    # Laravel: composer.json contains laravel/framework
    if [ -f "composer.json" ] && grep -q '"laravel/framework"' composer.json 2>/dev/null; then
        echo "laravel"
        return
    fi

    # Django: manage.py present, or requirements.txt contains django
    if [ -f "manage.py" ]; then
        echo "django"
        return
    fi
    if [ -f "requirements.txt" ] && grep -qi "^django" requirements.txt 2>/dev/null; then
        echo "django"
        return
    fi

    # Next.js: package.json contains "next" as a dependency
    if [ -f "package.json" ] && grep -q '"next"' package.json 2>/dev/null; then
        echo "nextjs"
        return
    fi

    # Rails: Gemfile contains gem 'rails' or gem "rails"
    if [ -f "Gemfile" ] && grep -qE "gem ['\"]rails['\"]" Gemfile 2>/dev/null; then
        echo "rails"
        return
    fi

    # Generic Node.js: package.json present (no specific framework above matched)
    if [ -f "package.json" ]; then
        echo "node"
        return
    fi

    # Generic Python: requirements.txt or Pipfile present
    if [ -f "requirements.txt" ] || [ -f "Pipfile" ]; then
        echo "python"
        return
    fi

    echo ""
}

# Detect Docker Compose presence
detect_docker_compose() {
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || \
       [ -f "compose.yml" ] || [ -f "compose.yaml" ]; then
        echo "true"
    else
        echo ""
    fi
}

# Interactive framework selection fallback
prompt_framework() {
    echo ""
    echo "  What kind of project is this? (press Enter to skip)"
    echo ""
    echo "    1) Laravel    (./project init laravel)"
    echo "    2) Django     (./project init django)"
    echo "    3) Next.js    (./project init nextjs)"
    echo "    4) Rails      (./project init rails)"
    echo "    5) Node.js    (./project init node)"
    echo "    6) Python     (./project init python)"
    echo "    7) Skip"
    echo ""
    read -p "  Choice [7]: " -r FRAMEWORK_CHOICE
    echo ""
    case "$FRAMEWORK_CHOICE" in
        1) echo "laravel" ;;
        2) echo "django" ;;
        3) echo "nextjs" ;;
        4) echo "rails" ;;
        5) echo "node" ;;
        6) echo "python" ;;
        *) echo "" ;;
    esac
}

# Print the post-install recommendation
print_recommendation() {
    local framework="$1"
    local has_docker="$2"

    if [ -n "$framework" ]; then
        local init_cmd="./project init ${framework}"
        if [ -n "$has_docker" ]; then
            init_cmd="./project init ${framework} docker"
        fi

        if [ -n "$has_docker" ]; then
            echo -e "${GREEN}✓ Detected ${framework} project + Docker Compose${NC}"
        else
            echo -e "${GREEN}✓ Detected ${framework} project${NC}"
        fi
        echo ""
        echo "  Run this to add starter commands:"
        echo -e "    ${BLUE}${init_cmd}${NC}"
        echo ""
        echo "  Or run without arguments to see all available templates:"
        echo -e "    ${BLUE}./project init${NC}"
    else
        echo "  Add starter commands anytime:"
        echo -e "    ${BLUE}./project init${NC}"
    fi
}

# Check if we're in a project directory
check_project() {
    if [ -d "${PROJECT_DIR}" ]; then
        echo -e "${YELLOW}Warning: ${PROJECT_DIR} directory already exists${NC}"
        read -p "Continue with installation? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    fi
}

# Create directory structure
create_directories() {
    echo -e "${BLUE}Creating directory structure...${NC}"
    mkdir -p "${RUNTIME_DIR}"
    mkdir -p "${COMMANDS_DIR}"

    # Create .gitignore for runtime directory
    cat > "${RUNTIME_DIR}/.gitignore" << 'EOF'
# Ignore all binaries
command-runner*

# But keep this gitignore
!.gitignore
EOF

    echo -e "${GREEN}✓ Created ${PROJECT_DIR} directory structure${NC}"
}

# Download runner bootstrap script
download_runner() {
    echo -e "${BLUE}Downloading runner bootstrap script...${NC}"

    local runner_url="https://github.com/project-actions-org/project-actions-runner/releases/latest/download/${RUNNER_SCRIPT}"
    local runner_path="${RUNTIME_DIR}/${RUNNER_SCRIPT}"

    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "${runner_url}" -o "${runner_path}"
    elif command -v wget > /dev/null 2>&1; then
        wget -q "${runner_url}" -O "${runner_path}"
    else
        echo -e "${RED}Error: Neither curl nor wget is available${NC}"
        exit 1
    fi

    chmod +x "${runner_path}"
    echo -e "${GREEN}✓ Downloaded runner bootstrap script${NC}"
}

# Create project wrapper script
create_wrapper() {
    echo -e "${BLUE}Creating project wrapper script...${NC}"

    cat > "${PROJECT_SCRIPT}" << 'EOF'
#!/bin/bash
#
# Project Actions Wrapper Script
#
# This script provides a convenient entry point for running project commands.
# It delegates to the runner bootstrap script which handles downloading and
# executing the appropriate command-runner binary for your platform.
#

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the runner bootstrap script
RUNNER="${SCRIPT_DIR}/.project/.runtime/runner.sh"

# Check if runner exists
if [ ! -f "${RUNNER}" ]; then
    echo "Error: Runner not found at ${RUNNER}"
    echo "Please run the installation script first:"
    echo "  curl -fsSL https://project-actions.org/install.sh | bash"
    exit 1
fi

# Execute the runner with the script name and all arguments
PROJECT_SCRIPT_NAME="$(basename "$0")" "${RUNNER}" "$@"
EOF

    chmod +x "${PROJECT_SCRIPT}"
    echo -e "${GREEN}✓ Created ${PROJECT_SCRIPT} wrapper script${NC}"
}

# Main installation
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Project Actions Installation${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""

    # Detect platform
    PLATFORM=$(detect_platform)
    echo -e "Platform: ${GREEN}${PLATFORM}${NC}"
    echo ""

    # Check existing project
    check_project

    # Create directories
    create_directories

    # Download runner
    download_runner

    # Create wrapper script
    create_wrapper

    # Detect project framework and Docker Compose
    FRAMEWORK=$(detect_framework)
    HAS_DOCKER=$(detect_docker_compose)

    # If no framework detected, ask interactively
    if [ -z "$FRAMEWORK" ]; then
        FRAMEWORK=$(prompt_framework)
    fi

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""

    print_recommendation "$FRAMEWORK" "$HAS_DOCKER"

    echo ""
    echo "Documentation:"
    echo "  https://project-actions.org/docs"
    echo ""
}

main
