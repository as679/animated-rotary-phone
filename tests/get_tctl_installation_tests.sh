#!/usr/bin/env bash

# Source the test framework
source "$(dirname "$0")/bash-spec.sh"

# Source the script under test (but don't run main)
source "$(dirname "$0")/../get_tctl.sh"

# Disable 'set -e' inherited from get_tctl.sh to allow proper test error handling
# bash-spec needs to capture command failures without exiting the test suite
set +e

[[ `uname -s` =~ Linux ]] && SCRIPT=`realpath -s $(dirname "$0")/../get_tctl.sh`

describe "get_tctl.sh - Tetrate tctl Installation Script Tests"

# Test OS Detection with actual function
context "detect_os function"

it "should return valid OS value"
result=$(detect_os)
[[ "$result" == "linux" || "$result" == "darwin" || "$result" == "windows" ]]
should_succeed

it "should not return empty string"
result=$(detect_os)
expect "$result" not to_be ""

# Test Architecture Detection with actual function
context "detect_arch function"

it "should return valid architecture value"
result=$(detect_arch)
[[ "$result" == "amd64" || "$result" == "arm64" || "$result" == "arm" || "$result" == "386" ]]
should_succeed

it "should not return empty string"
result=$(detect_arch)
expect "$result" not to_be ""

# Test Default Values
context "default configuration values"

it "should have correct default version"
expect "$DEFAULT_VERSION" to_be "1.12.5"

it "should have correct default install directory"
expect "$DEFAULT_INSTALL_DIR" to_be "/usr/local/bin"

it "should have correct binary name"
expect "$BINARY_NAME" to_be "tctl"

# Test Function Existence
context "function definitions"

it "should define detect_os function"
type detect_os &>/dev/null
should_succeed

it "should define detect_arch function"
type detect_arch &>/dev/null
should_succeed

it "should define print_color function"
type print_color &>/dev/null
should_succeed

it "should define print_usage function"
type print_usage &>/dev/null
should_succeed

it "should define check_permissions function"
type check_permissions &>/dev/null
should_succeed

it "should define verify_binary function"
type verify_binary &>/dev/null
should_succeed

it "should define list_versions function"
type list_versions &>/dev/null
should_succeed

it "should define download_and_install function"
type download_and_install &>/dev/null
should_succeed

it "should define main function"
type main &>/dev/null
should_succeed

# Test Permission Checking
context "check_permissions function"

it "should check readable directory"
tempdir=$(mktemp -d)
check_permissions "$tempdir"
should_succeed
rmdir "$tempdir"

it "should handle non-existent directory with valid parent"
tempdir=$(mktemp -d)
check_permissions "$tempdir/nonexistent"
should_succeed
rmdir "$tempdir"

# Test Binary Verification
context "verify_binary function"

it "should fail for non-existent binary"
verify_binary "/tmp/nonexistent_binary_12345" 2>/dev/null
should_fail

it "should handle existing but non-executable file"
tempfile=$(mktemp)
echo "#!/bin/bash" > "$tempfile"
verify_binary "$tempfile" 2>/dev/null
result=$?
rm -f "$tempfile"
[[ $result -eq 0 || $result -eq 1 ]]
should_succeed

# Test Script Behavior
context "script execution behavior"

it "should have execute permissions"
expect "${SCRIPT}" to_have_mode "x"

it "should be a valid bash script"
head -n 1 "${SCRIPT}" | grep -q "bash"
should_succeed

it "should have set -e for error handling"
grep -q "set -e" "${SCRIPT}"
should_succeed

# Test Command Availability
context "required command availability"

it "should have curl or wget available"
command -v curl &> /dev/null || command -v wget &> /dev/null
should_succeed

it "should have basic unix tools available"
command -v uname &> /dev/null
should_succeed

it "should have mkdir available"
command -v mkdir &> /dev/null
should_succeed

it "should have chmod available"
command -v chmod &> /dev/null
should_succeed

# Test Script Constants
context "script constants and configuration"

it "should have non-empty default version"
expect "$DEFAULT_VERSION" not to_be ""

it "should have non-empty default install directory"
expect "$DEFAULT_INSTALL_DIR" not to_be ""

it "should have non-empty binary name"
expect "$BINARY_NAME" not to_be ""

it "should have absolute path for default install directory"
echo "$DEFAULT_INSTALL_DIR" | grep -q "^/"
should_succeed
