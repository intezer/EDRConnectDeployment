#!/bin/bash
# Intezer Endpoint Scanner Script
# Version 1.0.0
#
# This script downloads the Intezer Endpoint Scanner and runs it.
# It requires an Intezer API key as an argument.
# The script will download the scanner to the current directory and execute it, then delete the scanner.
# Supports Linux and macOS (detected automatically via uname).

set -eo pipefail

INTEZER_API_KEY=""
PROXY_URL=""
PROXY_USER=""
PROXY_PASSWORD=""
JWT_TOKEN=""
SCANNER_DOWNLOAD_PATH="/tmp/intezer-scanner"
LOGS_DIR=""
SOURCE=""
ENDPOINT_ANALYSIS_ID=""
ANALYZE_URL="https://analyze.intezer.com"
URL_PROVIDED="0"
PLATFORM=""

detect_platform() {
    local os_name
    os_name=$(uname -s)
    case "$os_name" in
        Linux)
            PLATFORM="linux"
            ;;
        Darwin)
            PLATFORM="mac"
            ;;
        *)
            echo "Error: Unsupported operating system: $os_name" >&2
            exit 1
            ;;
    esac
}

get_access_token() {
    local get_token_url="$ANALYZE_URL/api/v2-0/get-access-token"
    local get_access_token_response=""

    if command -v curl >/dev/null 2>&1; then
        local curl_proxy_args=()
        if should_use_proxy; then
            curl_proxy_args+=(--proxy "$PROXY_URL")
            if should_use_proxy_credentials; then
                curl_proxy_args+=(--proxy-user "$PROXY_USER:$PROXY_PASSWORD")
            fi
        fi
        get_access_token_response=$(curl "${curl_proxy_args[@]}" -s -X POST "$get_token_url" -H "Content-Type: application/json" -d "{\"api_key\":\"$INTEZER_API_KEY\"}")
    elif command -v wget >/dev/null 2>&1; then
        local wget_proxy_env=""
        local wget_proxy_args=()
        if should_use_proxy; then
            wget_proxy_env="$PROXY_URL"
            if should_use_proxy_credentials; then
                wget_proxy_args+=("--proxy-user=$PROXY_USER" "--proxy-password=$PROXY_PASSWORD")
            fi
        fi
        get_access_token_response=$(https_proxy=$wget_proxy_env wget "${wget_proxy_args[@]}" -q -O - "$get_token_url" --header="Content-Type: application/json" --post-data="{\"api_key\":\"$INTEZER_API_KEY\"}")
    else
        echo "Error: Neither curl nor wget is installed. Please install either of them." >&2
        exit 1
    fi

    local access_token
    access_token=$(echo "$get_access_token_response" | grep -o '"result":"[^"]*' | sed 's/"result":"//' || true)

    if [ -z "$access_token" ]; then
        echo "Error: Failed to get access token." >&2
        exit 1
    fi

    echo "$access_token"
}

should_use_proxy() {
    [ -n "$PROXY_URL" ]
}

should_use_proxy_credentials() {
    [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASSWORD" ]
}

get_with_wget() {
    local scanner_download_url="$ANALYZE_URL/api/v2-0/endpoint-scanner/download/$PLATFORM"
    local wget_proxy_env=""
    local wget_proxy_args=()
    if should_use_proxy; then
        wget_proxy_env="$PROXY_URL"
        if should_use_proxy_credentials; then
            wget_proxy_args+=("--proxy-user=$PROXY_USER" "--proxy-password=$PROXY_PASSWORD")
        fi
    fi

    # Get the redirected URL without following it (|| true: wget exits non-zero on 3xx)
    local redirect_url
    redirect_url=$(https_proxy=$wget_proxy_env wget "${wget_proxy_args[@]}" --method GET --timeout=30 --max-redirect=0 --header "Authorization: Bearer $JWT_TOKEN" "$scanner_download_url" 2>&1 | grep -i '[Ll]ocation' | sed -e 's/[Ll]ocation: //' | tr -d '\r' || true)

    # Remove trailing whitespace
    redirect_url=$(echo "$redirect_url" | cut -d ' ' -f 1)

    if [ -z "$redirect_url" ]; then
        echo "Error: No redirect URL found." >&2
        exit 1
    fi

    # Second wget command to download the file from the redirected URL
    https_proxy=$wget_proxy_env wget "${wget_proxy_args[@]}" "$redirect_url" -O "$SCANNER_DOWNLOAD_PATH"

    chmod +x "$SCANNER_DOWNLOAD_PATH"
    echo "Download completed successfully."
}

get_with_curl() {
    local scanner_download_url="$ANALYZE_URL/api/v2-0/endpoint-scanner/download/$PLATFORM"
    local http_code

    if should_use_proxy; then
        if should_use_proxy_credentials; then
            http_code=$(curl --location "$scanner_download_url" --header "Authorization: Bearer $JWT_TOKEN" --proxy "$PROXY_URL" --proxy-user "$PROXY_USER:$PROXY_PASSWORD" --output "$SCANNER_DOWNLOAD_PATH" --write-out "%{http_code}" -s)
        else
            http_code=$(curl --location "$scanner_download_url" --header "Authorization: Bearer $JWT_TOKEN" --proxy "$PROXY_URL" --output "$SCANNER_DOWNLOAD_PATH" --write-out "%{http_code}" -s)
        fi
    else
        http_code=$(curl --location "$scanner_download_url" --header "Authorization: Bearer $JWT_TOKEN" --output "$SCANNER_DOWNLOAD_PATH" --write-out "%{http_code}" -s)
    fi

    # --location follows redirects, so 3xx is never seen here
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        chmod +x "$SCANNER_DOWNLOAD_PATH"
        echo "Download completed successfully."
    else
        echo "Error: Download failed with HTTP status $http_code." >&2
        cat "$SCANNER_DOWNLOAD_PATH" >&2
        exit 1
    fi
}

run_scanner() {
    local cmd=("$SCANNER_DOWNLOAD_PATH" -k "$INTEZER_API_KEY")

    local proxy_url_without_protocol="${PROXY_URL#*://}"
    local proxy_protocol=""
    if [ "$proxy_url_without_protocol" != "$PROXY_URL" ]; then
        proxy_protocol="${PROXY_URL%%://*}://"
    fi
    # scanner gets proxy as https://user:pass@url:port
    if should_use_proxy; then
        if should_use_proxy_credentials; then
            cmd+=(-p "${proxy_protocol}${PROXY_USER}:${PROXY_PASSWORD}@${proxy_url_without_protocol}")
        else
            cmd+=(-p "${proxy_protocol}${proxy_url_without_protocol}")
        fi
    fi

    if [ -n "$LOGS_DIR" ]; then
        cmd+=(-l "$LOGS_DIR")
    fi
    if [ -n "$SOURCE" ]; then
        cmd+=(-s "$SOURCE")
    fi
    if [ -n "$ENDPOINT_ANALYSIS_ID" ]; then
        cmd+=(-i "$ENDPOINT_ANALYSIS_ID")
    fi
    if [ "$URL_PROVIDED" = "1" ]; then
        cmd+=(-u "$ANALYZE_URL")
    fi

    "${cmd[@]}"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -k|--api-key)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            INTEZER_API_KEY="$2"
            shift 2
            ;;
            -p|--proxy-url)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            PROXY_URL="$2"
            shift 2
            ;;
            --proxy-user)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            PROXY_USER="$2"
            shift 2
            ;;
            --proxy-password)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            PROXY_PASSWORD="$2"
            shift 2
            ;;
            -l|--logs-dir)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            LOGS_DIR="$2"
            shift 2
            ;;
            -s|--source)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            SOURCE="$2"
            shift 2
            ;;
            -i|--endpoint-analysis-id)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            ENDPOINT_ANALYSIS_ID="$2"
            shift 2
            ;;
            -u|--url)
            [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
            ANALYZE_URL="$2"
            URL_PROVIDED="1"
            shift 2
            ;;
            *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
        esac
    done
}

ensure_key() {
    if [ -z "$INTEZER_API_KEY" ]; then
        echo "Error: Please provide an Intezer API key." >&2
        exit 1
    fi
}

ensure_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "Error: This script must be run as root." >&2
        exit 1
    fi
}

cleanup() { rm -f "$SCANNER_DOWNLOAD_PATH"; }

main() {
    cd /tmp
    ensure_root
    detect_platform
    parse_args "$@"
    ensure_key
    trap cleanup EXIT
    
    touch "$SCANNER_DOWNLOAD_PATH"
    chmod 700 "$SCANNER_DOWNLOAD_PATH"

    JWT_TOKEN=$(get_access_token)
    if command -v curl >/dev/null 2>&1; then
        get_with_curl
    elif command -v wget >/dev/null 2>&1; then
        get_with_wget
    else
        echo "Error: Neither curl nor wget is installed. Please install either of them." >&2
        exit 1
    fi
    run_scanner
}

main "$@"
