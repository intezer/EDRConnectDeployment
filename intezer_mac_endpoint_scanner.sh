#!/bin/bash
# Intezer macOS Endpoint Scanner Script
# Version 1.0.0
#
# This script downloads the Intezer macOS Endpoint Scanner and runs it.
# It requires an Intezer API key as an argument.
# The script will download the scanner to the current directory and execute it, then delete the scanner.

set -e

INTEZER_API_KEY=""
PROXY_URL=""
PROXY_USER=""
PROXY_PASSWORD=""
JWT_TOKEN=""
SCANNER_DOWNLOAD_PATH="./intezer-scanner"
LOGS_DIR=""
SOURCE=""
ENDPOINT_ANALYSIS_ID=""
ANALYZE_URL="https://analyze.intezer.com"
URL_PROVIDED="0"

get_access_token() {
    get_token_url="$ANALYZE_URL/api/v2-0/get-access-token"
    get_access_token_response=""

    if should_use_proxy; then
        if should_use_proxy_credentials; then
            proxy_args="--proxy-user $PROXY_USER:$PROXY_PASSWORD"
        else
            proxy_args="--proxy $PROXY_URL"
        fi
    fi
    get_access_token_response=$(curl ${proxy_args} -s -X POST "$get_token_url" -H "Content-Type: application/json" -d "{\"api_key\":\"$INTEZER_API_KEY\"}")

    access_token=$(echo "$get_access_token_response" | grep -o '"result":"[^"]*' | sed 's/"result":"//')

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

download_scanner() {
    scanner_download_url="$ANALYZE_URL/api/v2-0/endpoint-scanner/download/mac"
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

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        chmod +x "$SCANNER_DOWNLOAD_PATH"
        echo "Download completed successfully."
    else
        echo "Error: Download failed with HTTP status $http_code." >&2
        cat "$SCANNER_DOWNLOAD_PATH" >&2
        exit 1
    fi
}

run_scanner() {
    local scanner_cmd="$SCANNER_DOWNLOAD_PATH -k \"$INTEZER_API_KEY\""
    local proxy_args=""
    local extra_args=""

    local proxy_url_without_protocol="${PROXY_URL#*://}"
    local proxy_protocol=""
    if [ "$proxy_url_without_protocol" != "$PROXY_URL" ]; then
            local proxy_protocol="${PROXY_URL%%://*}://"
    fi
    # scanner gets proxy as https://user:pass@url:port
    if should_use_proxy; then
        if should_use_proxy_credentials; then
            proxy_args="-p ${proxy_protocol}${PROXY_USER}:${PROXY_PASSWORD}@${proxy_url_without_protocol}"
        else
            proxy_args="-p ${proxy_protocol}${proxy_url_without_protocol}"
        fi
    fi

    if [ -n "$LOGS_DIR" ]; then
        extra_args="$extra_args -l \"$LOGS_DIR\""
    fi
    if [ -n "$SOURCE" ]; then
        extra_args="$extra_args -s \"$SOURCE\""
    fi
    if [ -n "$ENDPOINT_ANALYSIS_ID" ]; then
        extra_args="$extra_args -i \"$ENDPOINT_ANALYSIS_ID\""
    fi
    if [ "$URL_PROVIDED" = "1" ]; then
        extra_args="$extra_args -u \"$ANALYZE_URL\""
    fi

    eval "$scanner_cmd $proxy_args $extra_args"
    if [ $? -ne 0 ]; then
        echo "Error: Intezer scanner execution failed." >&2
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            -k|--api-key)
            INTEZER_API_KEY="$2"
            shift
            shift
            ;;
            -p|--proxy-url)
            PROXY_URL="$2"
            shift
            shift
            ;;
            --proxy-user)
            PROXY_USER="$2"
            shift
            shift
            ;;
            --proxy-password)
            PROXY_PASSWORD="$2"
            shift
            shift
            ;;
            -l|--logs-dir)
            LOGS_DIR="$2"
            shift
            shift
            ;;
            -s|--source)
            SOURCE="$2"
            shift
            shift
            ;;
            -i|--endpoint-analysis-id)
            ENDPOINT_ANALYSIS_ID="$2"
            shift
            shift
            ;;
            -u|--url)
            ANALYZE_URL="$2"
            URL_PROVIDED="1"
            shift
            shift
            ;;
            *)    # unknown option
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

main() {
    ensure_root
    parse_args "$@"
    ensure_key
    rm -f "$SCANNER_DOWNLOAD_PATH"
    touch "$SCANNER_DOWNLOAD_PATH"
    chmod 700 "$SCANNER_DOWNLOAD_PATH"

    JWT_TOKEN=$(get_access_token)
    download_scanner
    run_scanner
    rm -f "$SCANNER_DOWNLOAD_PATH"
}

main "$@"
