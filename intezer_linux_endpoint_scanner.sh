#!/bin/bash

# This script downloads the Intezer Linux Endpoint Scanner and runs it.
# It requires an Intezer API key as an argument.
# The script will download the scanner to the current directory and execute it, then delete the scanner.

set -e

get_access_token() {
    get_token_url="https://analyze.intezer.com/api/v2-0/get-access-token"
    get_access_token_response=""


    if command -v curl >/dev/null 2>&1; then
        if should_use_proxy; then
            if should_use_proxy_credentials; then
                proxy_args="--proxy-user $PROXY_USER:$PROXY_PASSWORD"
                get_access_token_response=$(curl $proxy_args -s -X POST "$get_token_url" -H "Content-Type: application/json" -d "{\"api_key\":\"$INTEZER_API_KEY\"}")
            else 
                proxy_args="--proxy $PROXY_URL"
                get_access_token_response=$(curl $proxy_args -s -X POST "$get_token_url" -H "Content-Type: application/json" -d "{\"api_key\":\"$INTEZER_API_KEY\"}")
            fi
        else
            get_access_token_response=$(curl -s -X POST "$get_token_url" -H "Content-Type: application/json" -d "{\"api_key\":\"$INTEZER_API_KEY\"}")
    fi
    elif command -v wget >/dev/null 2>&1; then
        if should_use_proxy; then
            if should_use_proxy_credentials; then
                proxy_args="--proxy-user=$PROXY_USER --proxy-password=$PROXY_PASSWORD"
                get_access_token_response=$(https_proxy=$PROXY_URL wget $proxy_args -q -O - "$get_token_url" --header="Content-Type: application/json" --post-data="{\"api_key\":\"$INTEZER_API_KEY\"}")
            fi
        else
            get_access_token_response=$(wget -q -O - "$get_token_url" --header="Content-Type: application/json" --post-data="{\"api_key\":\"$INTEZER_API_KEY\"}")
        fi
    else
        echo "Error: Neither curl nor wget is installed. Please install either of them." >&2
        exit 1
    fi

    access_token=$(echo "$get_access_token_response" | grep -o '"result":"[^"]*' | sed 's/"result":"//')

    if [ -z "$access_token" ]; then
        echo "Error: Failed to get access token." >&2
        exit 1
    fi

    export JWT_TOKEN="$access_token"
}

should_use_proxy() {
    [ -n "$PROXY_URL" ]
}

should_use_proxy_credentials() {
    [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASSWORD" ]
}

get_with_wget() {
    scanner_download_url="https://analyze.intezer.com/api/v2-0/endpoint-scanner/download/linux"
    get_access_token
    # First wget command to get the redirected URL (without following it)
    redirect_url=$(wget --method GET --timeout=0 --max-redirect=0 --header "Authorization: Bearer $JWT_TOKEN" "$scanner_download_url" 2>&1 | grep -i Location | sed -e 's/Location: //')

    # Remove whitespace from redirect_url
    redirect_url=$(echo "$redirect_url" | cut -d ' ' -f 1)

    # Check if the redirect URL is empty
    if [ -z "$redirect_url" ]; then
        echo "No redirect URL found."
        exit 1
    fi

    # Second wget command to download the file from the redirected URL
    if should_use_proxy; then
        if should_use_proxy_credentials; then
            https_proxy=$PROXY_URL wget --proxy-user="$PROXY_USER" --proxy-password="$PROXY_PASSWORD" "$redirect_url" -O intezer-scanner
        else
            https_proxy=$PROXY_URL wget "$redirect_url" -O intezer-scanner
        fi
    else
        wget "$redirect_url" -O intezer-scanner
    fi

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        echo "Download completed successfully."
    else
        echo "Download failed."
    fi
}

get_with_curl() {
    scanner_download_url="https://analyze.intezer.com/api/v2-0/endpoint-scanner/download/linux"
    get_access_token

    # Check if the download was successful
    if should_use_proxy; then
        if should_use_proxy_credentials; then
            curl --location "$scanner_download_url" --header "Authorization: Bearer $JWT_TOKEN" --proxy "$PROXY_URL" --proxy-user "$PROXY_USER:$PROXY_PASSWORD" --output intezer-scanner
        else
            curl --location "$scanner_download_url" --header "Authorization: Bearer $JWT_TOKEN" --proxy "$PROXY_URL" --output intezer-scanner
        fi
    else
        curl --location "$scanner_download_url" --header "Authorization: Bearer $JWT_TOKEN" --output intezer-scanner
    fi

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        echo "Download completed successfully."
    else
        echo "Download failed."
    fi
}

run_scanner() {
    local scanner_cmd="./intezer-scanner -k \"$INTEZER_API_KEY\""
    local proxy_args=""
    
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

    eval "$scanner_cmd $proxy_args"

    if [ $? -ne 0 ]; then
        echo "Error: Intezer scanner execution failed." >&2
        exit 1
    fi
}



INTEZER_API_KEY=""
PROXY_URL=""
PROXY_USER=""
PROXY_PASSWORD=""
JWT_TOKEN=""

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -k|--api-key)
        INTEZER_API_KEY="$2"
        shift # past argument
        shift # past value
        ;;
        -p|--proxy-url)
        PROXY_URL="$2"
        shift # past argument
        shift # past value
        ;;
        -u|--proxy-user)
        PROXY_USER="$2"
        shift # past argument
        shift # past value
        ;;
        -s|--proxy-password)
        PROXY_PASSWORD="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        echo "Error: Unknown option: $1" >&2
        exit 1
        ;;
    esac
done

if [ -z "$INTEZER_API_KEY" ]; then
    echo "Error: Please provide an Intezer API key." >&2
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

rm -f intezer-scanner
touch intezer-scanner
chmod 700 intezer-scanner

if command -v curl >/dev/null 2>&1; then
    get_with_curl
elif command -v wget >/dev/null 2>&1; then
    get_with_wget
else
    echo "Error: Neither curl nor wget is installed. Please install either of them." >&2
    exit 1
fi
run_scanner
rm -f intezer-scanner
