#!/bin/bash

# Tetrate Service Bridge tctl Installation Script
# Automatically detects OS and architecture to download the correct binary
# Repository: https://binaries.dl.tetrate.io/public/raw/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_VERSION="1.12.5"
DEFAULT_INSTALL_DIR="/usr/local/bin"
BINARY_NAME="tctl"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automatically downloads and installs the correct tctl binary for your system.

OPTIONS:
    -v, --version VERSION    TSB version to install (default: ${DEFAULT_VERSION})
    -d, --dir DIRECTORY      Installation directory (default: ${DEFAULT_INSTALL_DIR})
    -h, --help              Display this help message
    --list-versions         List available versions
    --dry-run              Show what would be installed without actually downloading

EXAMPLES:
    # Install default version
    ./install-tctl.sh

    # Install specific version
    ./install-tctl.sh -v 1.12.5

    # Install to custom directory
    ./install-tctl.sh -d ~/bin

    # Check what would be installed
    ./install-tctl.sh --dry-run

SUPPORTED PLATFORMS:
    - Linux (AMD64, ARM64)
    - macOS (Intel/AMD64, Apple Silicon/ARM64)
    - Windows (AMD64) - WSL recommended

EOF
}

# Function to detect OS
detect_os() {
    local os=""
    local uname_output=$(uname -s)

    case "${uname_output}" in
        Linux*)
            os="linux"
            ;;
        Darwin*)
            os="darwin"
            ;;
        MINGW*|CYGWIN*|MSYS*)
            os="windows"
            ;;
        *)
            print_color "${RED}" "Error: Unsupported operating system: ${uname_output}"
            exit 1
            ;;
    esac

    echo "${os}"
}

# Function to detect architecture
detect_arch() {
    local arch=""
    local uname_output=$(uname -m)

    case "${uname_output}" in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l|armv7|arm)
            arch="arm"
            ;;
        i386|i686)
            arch="386"
            ;;
        *)
            print_color "${RED}" "Error: Unsupported architecture: ${uname_output}"
            exit 1
            ;;
    esac

    echo "${arch}"
}

# Function to check if running with required permissions
check_permissions() {
    local install_dir=$1

    # Check if we can write to the installation directory
    if [ -d "${install_dir}" ]; then
        if [ ! -w "${install_dir}" ]; then
            if [ "$EUID" -ne 0 ]; then
                print_color "${YELLOW}" "Warning: Cannot write to ${install_dir}. You may need to run with sudo."
                return 1
            fi
        fi
    else
        # Directory doesn't exist, check parent
        local parent_dir=$(dirname "${install_dir}")
        if [ ! -w "${parent_dir}" ]; then
            if [ "$EUID" -ne 0 ]; then
                print_color "${YELLOW}" "Warning: Cannot create ${install_dir}. You may need to run with sudo."
                return 1
            fi
        fi
    fi

    return 0
}

# Function to verify binary after download
verify_binary() {
    local binary_path=$1

    if [ ! -f "${binary_path}" ]; then
        print_color "${RED}" "Error: Binary not found at ${binary_path}"
        return 1
    fi

    # Check if it's executable
    if [ ! -x "${binary_path}" ]; then
        chmod +x "${binary_path}"
    fi

    # Try to run version command
    # On macOS, we might need to handle Gatekeeper
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Remove quarantine attribute on macOS
        xattr -d com.apple.quarantine "${binary_path}" 2>/dev/null || true
    fi

    if "${binary_path}" version &>/dev/null; then
        print_color "${GREEN}" "✓ Binary verified successfully"
        return 0
    else
        print_color "${YELLOW}" "⚠ Binary downloaded but could not verify version"
        return 0
    fi
}

# Function to list available versions
list_versions() {
    print_color "${BLUE}" "Fetching available versions..."

    # Common versions (you can expand this list or fetch dynamically)
    cat << EOF

Available TSB versions:
  - 1.12.5 (latest stable)
  - 1.12.4
  - 1.12.3
  - 1.12.2
  - 1.12.1
  - 1.12.0
  - 1.11.3
  - 1.11.2
  - 1.11.1
  - 1.11.0
  - 1.10.4
  - 1.10.3
  - 1.10.2
  - 1.10.1
  - 1.10.0

For a complete list, visit: https://docs.tetrate.io/service-bridge/latest/en-us/release-notes

EOF
}

# Function to download and install
download_and_install() {
    local version=$1
    local install_dir=$2
    local os=$3
    local arch=$4
    local dry_run=$5

    # Construct download URL
    local platform="${os}-${arch}"
    local binary_suffix=""

    if [ "${os}" = "windows" ]; then
        binary_suffix=".exe"
    fi

    local download_url="https://binaries.dl.tetrate.io/public/raw/versions/${platform}-${version}/${BINARY_NAME}${binary_suffix}"
    local install_path="${install_dir}/${BINARY_NAME}"

    print_color "${BLUE}" "\n=== Installation Details ==="
    echo "OS:           ${os}"
    echo "Architecture: ${arch}"
    echo "Version:      ${version}"
    echo "Download URL: ${download_url}"
    echo "Install Path: ${install_path}"

    if [ "${dry_run}" = "true" ]; then
        print_color "${YELLOW}" "\n[DRY RUN] Would download from: ${download_url}"
        print_color "${YELLOW}" "[DRY RUN] Would install to: ${install_path}"
        return 0
    fi

    # Check permissions
    if ! check_permissions "${install_dir}"; then
        print_color "${YELLOW}" "\nTrying with sudo..."
        SUDO_PREFIX="sudo"
    else
        SUDO_PREFIX=""
    fi

    # Create install directory if it doesn't exist
    if [ ! -d "${install_dir}" ]; then
        print_color "${BLUE}" "Creating directory: ${install_dir}"
        ${SUDO_PREFIX} mkdir -p "${install_dir}"
    fi

    # Backup existing binary if it exists
    if [ -f "${install_path}" ]; then
        print_color "${YELLOW}" "Backing up existing binary to ${install_path}.backup"
        ${SUDO_PREFIX} mv "${install_path}" "${install_path}.backup"
    fi

    # Download the binary
    print_color "${BLUE}" "\nDownloading tctl..."

    # Check for available download tools and use appropriate options
    if command -v curl &> /dev/null; then
        # Use curl with appropriate options for Linux and macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS curl options
            ${SUDO_PREFIX} curl -L -o "${install_path}" "${download_url}" --progress-bar --fail --silent --show-error
        else
            # Linux curl options
            ${SUDO_PREFIX} curl -L -o "${install_path}" "${download_url}" --progress-bar --fail
        fi
    elif command -v wget &> /dev/null; then
        ${SUDO_PREFIX} wget -O "${install_path}" "${download_url}" --show-progress
    else
        print_color "${RED}" "Error: Neither curl nor wget is available. Please install one of them."
        exit 1
    fi

    # Check if download was successful
    if [ $? -ne 0 ] || [ ! -f "${install_path}" ]; then
        print_color "${RED}" "Error: Failed to download tctl"

        # Restore backup if it exists
        if [ -f "${install_path}.backup" ]; then
            print_color "${YELLOW}" "Restoring backup..."
            ${SUDO_PREFIX} mv "${install_path}.backup" "${install_path}"
        fi
        exit 1
    fi

    # Make binary executable
    print_color "${BLUE}" "Setting executable permissions..."
    ${SUDO_PREFIX} chmod +x "${install_path}"

    # On macOS, handle Gatekeeper and quarantine
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_color "${BLUE}" "Handling macOS security settings..."
        # Remove quarantine attribute
        ${SUDO_PREFIX} xattr -d com.apple.quarantine "${install_path}" 2>/dev/null || true
        # Clear extended attributes that might prevent execution
        ${SUDO_PREFIX} xattr -cr "${install_path}" 2>/dev/null || true
    fi

    # Verify the binary
    print_color "${BLUE}" "\nVerifying installation..."
    if verify_binary "${install_path}"; then
        # Remove backup on successful verification
        if [ -f "${install_path}.backup" ]; then
            ${SUDO_PREFIX} rm "${install_path}.backup"
        fi

        print_color "${GREEN}" "\n✓ tctl ${version} installed successfully!"

        # Check if install_dir is in PATH
        if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
            print_color "${YELLOW}" "\n⚠ Note: ${install_dir} is not in your PATH."
            print_color "${YELLOW}" "  Add it to your PATH by running:"
            print_color "${BLUE}" "    export PATH=\"${install_dir}:\$PATH\""

            # Detect shell and provide appropriate config file
            if [[ "$SHELL" == *"zsh"* ]]; then
                print_color "${YELLOW}" "  To make it permanent, add the above line to your ~/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]]; then
                print_color "${YELLOW}" "  To make it permanent, add the above line to your ~/.bashrc"
            else
                print_color "${YELLOW}" "  To make it permanent, add the above line to your shell's config file"
            fi
        fi
    else
        print_color "${YELLOW}" "\n⚠ Installation completed but could not verify"
    fi

    # Print version info
    echo ""
    ${install_path} version 2>/dev/null || true
}

# Main script
main() {
    local version="${DEFAULT_VERSION}"
    local install_dir="${DEFAULT_INSTALL_DIR}"
    local dry_run="false"
    local show_help="false"
    local show_versions="false"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                version="$2"
                shift 2
                ;;
            -d|--dir)
                install_dir="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -h|--help)
                show_help="true"
                shift
                ;;
            --list-versions)
                show_versions="true"
                shift
                ;;
            *)
                print_color "${RED}" "Error: Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Show help if requested
    if [ "${show_help}" = "true" ]; then
        print_usage
        exit 0
    fi

    # List versions if requested
    if [ "${show_versions}" = "true" ]; then
        list_versions
        exit 0
    fi

    # Print banner
    print_color "${BLUE}" "╔══════════════════════════════════════════╗"
    print_color "${BLUE}" "║  Tetrate Service Bridge tctl Installer  ║"
    print_color "${BLUE}" "╚══════════════════════════════════════════╝"

    # Detect OS and architecture
    print_color "${BLUE}" "\nDetecting system information..."
    OS=$(detect_os)
    ARCH=$(detect_arch)

    # Special handling for Windows
    if [ "${OS}" = "windows" ]; then
        print_color "${YELLOW}" "\n⚠ Windows detected. Note:"
        print_color "${YELLOW}" "  - WSL (Windows Subsystem for Linux) is recommended"
        print_color "${YELLOW}" "  - Native Windows binary requires .exe extension"
        print_color "${YELLOW}" "  - Consider running this script from WSL instead"
        echo ""
        read -p "Continue with Windows installation? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_color "${YELLOW}" "Installation cancelled."
            exit 0
        fi
    fi

    # Perform installation
    download_and_install "${version}" "${install_dir}" "${OS}" "${ARCH}" "${dry_run}"

    if [ "${dry_run}" = "false" ]; then
        print_color "${GREEN}" "\n✅ Installation complete!"
        print_color "${BLUE}" "\nNext steps:"
        echo ""
        echo "# Configure TSB connection:"
        echo "tctl config clusters set default --bridge-address <tsb-fqdn>:443"
        echo "tctl config users set default --username <username> --password <password> --org <organization>"
        echo ""
        echo "# Verify connection:"
        echo "tctl get organizations"
        echo ""
        print_color "${BLUE}" "For more information, visit: https://docs.tetrate.io/service-bridge"
    fi
}

# Run main function
# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi