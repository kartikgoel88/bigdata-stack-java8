#!/bin/bash
# Error and failure handling utilities
# Source this script in other scripts to use error handling functions

# Color codes for output (if terminal supports it)
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if output is a terminal
if [ -t 1 ]; then
    USE_COLORS=true
else
    USE_COLORS=false
fi

# Log error message and exit with code
# Usage: log_error "Error message" [exit_code]
log_error() {
    local msg="$1"
    local exit_code="${2:-1}"
    if [ "$USE_COLORS" = true ]; then
        echo -e "${RED}ERROR:${NC} $msg" >&2
    else
        echo "ERROR: $msg" >&2
    fi
    return $exit_code
}

# Log error and exit
# Usage: die "Error message" [exit_code]
die() {
    log_error "$1" "${2:-1}"
    exit "${2:-1}"
}

# Log warning message
# Usage: log_warning "Warning message"
log_warning() {
    local msg="$1"
    if [ "$USE_COLORS" = true ]; then
        echo -e "${YELLOW}WARNING:${NC} $msg" >&2
    else
        echo "WARNING: $msg" >&2
    fi
}

# Log info message
# Usage: log_info "Info message"
log_info() {
    local msg="$1"
    echo "$msg"
}

# Log success message
# Usage: log_success "Success message"
log_success() {
    local msg="$1"
    if [ "$USE_COLORS" = true ]; then
        echo -e "${GREEN}SUCCESS:${NC} $msg"
    else
        echo "SUCCESS: $msg"
    fi
}

# Check if a directory exists, exit if not
# Usage: check_directory "directory_path" [error_message]
check_directory() {
    local dir="$1"
    local error_msg="${2:-Required directory $dir does not exist}"
    
    if [ ! -d "$dir" ]; then
        die "$error_msg"
    fi
}

# Check if a file exists, exit if not
# Usage: check_file "file_path" [error_message]
check_file() {
    local file="$1"
    local error_msg="${2:-Required file $file does not exist}"
    
    if [ ! -f "$file" ]; then
        die "$error_msg"
    fi
}

# Check if a command exists in PATH
# Usage: check_command "command_name" [error_message]
check_command() {
    local cmd="$1"
    local error_msg="${2:-Command $cmd not found in PATH}"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "$error_msg"
    fi
}

# Wait for a port to be available
# Usage: wait_for_port host port [retries] [retry_delay]
# Returns: 0 if port is available, 1 if timeout
wait_for_port() {
    local host="$1"
    local port="$2"
    local retries="${3:-60}"
    local delay="${4:-2}"
    
    for ((i=1; i<=retries; i++)); do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_info "$host:$port is reachable"
            return 0
        fi
        log_info "Waiting for $host:$port ($i/$retries)"
        sleep "$delay"
    done
    
    log_error "$host:$port not reachable after $retries attempts"
    return 1
}

# Retry a command with exponential backoff
# Usage: retry_command "command" [max_retries] [initial_delay]
# Returns: 0 if command succeeds, 1 if all retries fail
retry_command() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local delay="${3:-2}"
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        log_info "Executing command (attempt $attempt/$max_retries): $cmd"
        
        if eval "$cmd"; then
            log_success "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log_warning "Command failed on attempt $attempt, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_retries attempts: $cmd"
    return 1
}

# Retry a command with fixed delay
# Usage: retry_command_fixed "command" [max_retries] [delay]
# Returns: 0 if command succeeds, 1 if all retries fail
retry_command_fixed() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local delay="${3:-2}"
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        log_info "Executing command (attempt $attempt/$max_retries): $cmd"
        
        if eval "$cmd"; then
            log_success "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log_warning "Command failed on attempt $attempt, retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_retries attempts: $cmd"
    return 1
}

# Check if a command output contains a specific pattern (for error detection)
# Usage: check_output_contains "command" "pattern" [error_message]
check_output_contains() {
    local cmd="$1"
    local pattern="$2"
    local error_msg="${3:-Command output contains unexpected pattern}"
    
    local output
    output=$(eval "$cmd" 2>&1)
    
    if echo "$output" | grep -qi "$pattern"; then
        log_error "$error_msg"
        return 1
    fi
    
    return 0
}

# Validate environment variable is set
# Usage: check_env_var "VAR_NAME" [error_message]
check_env_var() {
    local var_name="$1"
    local error_msg="${2:-Environment variable $var_name is not set}"
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ]; then
        die "$error_msg"
    fi
}

# Safe command execution with error handling
# Usage: safe_exec "command" [error_message] [exit_on_error]
# If exit_on_error is true (default), exits on failure. Otherwise returns error code.
safe_exec() {
    local cmd="$1"
    local error_msg="${2:-Command failed: $cmd}"
    local exit_on_error="${3:-true}"
    
    if ! eval "$cmd"; then
        log_error "$error_msg"
        if [ "$exit_on_error" = "true" ]; then
            exit 1
        else
            return 1
        fi
    fi
    
    return 0
}

# Check if HDFS command is available and working
# Usage: check_hdfs_available [retries]
check_hdfs_available() {
    local retries="${1:-30}"
    local attempt=1
    
    while [ $attempt -le $retries ]; do
        if hdfs dfsadmin -report >/dev/null 2>&1; then
            log_info "HDFS NameNode is ready"
            return 0
        fi
        
        if [ $attempt -lt $retries ]; then
            log_info "Waiting for HDFS NameNode to be ready ($attempt/$retries)..."
            sleep 2
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_warning "HDFS NameNode may not be fully ready after $retries attempts"
    return 1
}

# Check if a file exists in multiple possible locations
# Usage: find_file_in_locations "filename" "location1" "location2" ...
# Sets FOUND_FILE variable and returns 0 if found, 1 if not found
find_file_in_locations() {
    local filename="$1"
    shift
    local locations=("$@")
    
    FOUND_FILE=""
    
    for location in "${locations[@]}"; do
        if [ -f "$location/$filename" ] || [ -f "$location" ]; then
            # Check if location is a file path or directory path
            if [ -f "$location" ]; then
                FOUND_FILE="$location"
            else
                FOUND_FILE="$location/$filename"
            fi
            
            log_info "Found file: $FOUND_FILE"
            return 0
        fi
    done
    
    log_error "File not found in any of the checked locations: ${locations[*]}"
    return 1
}

# Setup signal handlers for graceful shutdown
# Usage: setup_signal_handlers [handler_function]
# If no handler is provided, uses a default handler
setup_signal_handlers() {
    local handler="${1:-default_term_handler}"
    
    # Define default handler if none provided
    if [ "$handler" = "default_term_handler" ]; then
        default_term_handler() {
            log_info "Received termination signal"
            if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
                log_info "Terminating child process $child_pid"
                kill -TERM "$child_pid"
                wait "$child_pid"
            fi
            exit 0
        }
    fi
    
    trap "$handler" SIGTERM SIGINT
}

