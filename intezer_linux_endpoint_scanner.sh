#!/bin/bash

# This script downloads the Intezer Linux Endpoint Scanner and runs it.
# It requires an Intezer API key as an argument.
# The script will download the scanner to the current directory and execute it, then delete the scanner.

set -e
INTEZER_API_KEY="$1"

if [ -z "$INTEZER_API_KEY" ]; then
    echo "Error: Please provide an Intezer API key." >&2
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

get_access_token() {
    get_token_url="https://analyze.intezer.com/api/v2-0/get-access-token"
    get_access_token_response=""

    if command -v curl >/dev/null 2>&1; then
        get_access_token_response=$(curl -s -X POST "$get_token_url" -H "Content-Type: application/json" -d "{\"api_key\":\"$INTEZER_API_KEY\"}")
    elif command -v wget >/dev/null 2>&1; then
        get_access_token_response=$(wget -q -O - "$get_token_url" --header="Content-Type: application/json" --post-data="{\"api_key\":\"$INTEZER_API_KEY\"}")
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
  

  # Check if the download was successful
  if wget "$redirect_url" -O intezer-scanner; then
      echo "Download completed successfully."
  else
      echo "Download failed."
  fi
}


get_with_curl() {
  scanner_download_url="https://analyze.intezer.com/api/v2-0/endpoint-scanner/download/linux"
  get_access_token

  # Check if the download was successful
  if curl --location $scanner_download_url --header "Authorization: Bearer $JWT_TOKEN" --output intezer-scanner; then
      echo "Download completed successfully."
  else
      echo "Download failed."
  fi
}

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

./intezer-scanner -k "$INTEZER_API_KEY"
rm -f intezer-scanner
