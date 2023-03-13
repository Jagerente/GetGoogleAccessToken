#!/bin/bash

#######################################
# Variables
#######################################
readonly GREEN='\e[32m'
readonly BLUE='\e[34m'
readonly YELLOW='\e[33m'
readonly RED='\e[31m'
readonly NC='\e[0m'
readonly SERVICE_ACCOUNT_KEY_PATH="service-account-key.json"
readonly AUTH_SCOPE="https://www.googleapis.com/auth/drive"


#######################################
# Functions
#######################################

#######################################
# Prints error message
# Arguments:
#   Message
#######################################
function print_error () {
    printf "${RED}Error: %s${NC}\n" "${1}"
}

#######################################
# Prints info message
# Arguments:
#   Message
#######################################
function print_info () {
    printf "${GREEN}%s${NC}\n" "${1}"
}

#######################################
# Prints status message
# Arguments:
#   Message
#######################################
function print_status () {
    printf "${BLUE}%s${NC}\n" "${1}"
}

#######################################
# Prints curl response output
# Arguments:
#   Response from curl
#######################################
function print_response () {
    printf "${YELLOW}\nRESPONSE:\n%s${NC}\n\n\n" "${1}"
}

#######################################
# Checks whether curl was ok
# Arguments:
#   Variable from curl result to check
#######################################
function check_curl () {
    if [[ -z ${1} || ${1} = "null" ]]
    then
        print_error "curl request failed"
        exit 1
    fi
}

#######################################
# Installs required packages
# Arguments:
#   None
#######################################
function install_dependencies () {
    print_status "Looking for required dependencies."
    
    packages=(curl openssl jq)
    for pkg in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "${pkg}" | grep -q "install ok installed"; then
            sudo apt-get update
            break
        fi
    done
    
    for pkg in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "${pkg}" | grep -q "install ok installed"; then
            print_error "${pkg} package not found."
            print_status "Installing ${pkg} package."
            sudo apt-get install -y "${pkg}" || {
                print_error "Could not install ${pkg} package."
                exit 1
            }
        else
            print_info "${pkg} package already installed."
        fi
    done
}

#######################################
# Generate JWT token
# Globals:
#   SERVICE_ACCOUNT_KEY_PATH
#   AUTH_SCOPE
#   TOKEN_URI
# Arguments:
#   None
#######################################
function generate_jwt () {
    local private_key_path
    local client_email
    local jwt_header
    local jwt_claim_set
    local base64_jwt_header
    local base64_jwt_claim_set
    local base64_signature
    local response
    
    private_key_path="private-key.pem"
    
    print_status "Generating JWT token..."
    
    print_status "Looking for SERVICE_ACCOUNT_KEY_PATH..."
    if ! [ -f ${SERVICE_ACCOUNT_KEY_PATH} ]; then
        print_error "Google SERVICE_ACCOUNT_KEY_PATH not found."
        exit 1
    fi
    print_info "SERVICE_ACCOUNT_KEY_PATH loaded!"
    
    print_status "Looking for private_key_path..."
    if ! [ -f ${private_key_path} ]; then
        print_error "SERVICE_ACCOUNT_KEY_PATH not found."
        print_status "Creating private_key_path..."
        cat ${SERVICE_ACCOUNT_KEY_PATH} | jq -r .private_key > ${private_key_path}
        print_status "private_key_path created:"
        print_info "$(cat "${private_key_path}")"
    else
        print_info "private_key_path loaded!"
    fi
    
    print_status "Configuring JWT token..."
    
    print_status "Reading client_email from ${SERVICE_ACCOUNT_KEY_PATH}..."
    client_email=$(jq -r '.client_email' "$SERVICE_ACCOUNT_KEY_PATH")
    print_status "Reading TOKEN_URI from ${SERVICE_ACCOUNT_KEY_PATH}..."
    TOKEN_URI=$(jq -r '.token_uri' "$SERVICE_ACCOUNT_KEY_PATH")
    
    print_status "Creating jwt_header..."
    jwt_header='
    {
        "alg":"RS256",
        "typ":"JWT"
    }'
    
    print_status "Creating jwt_claim_set..."
    jwt_claim_set='
    {
        "iss":"'${client_email}'",
        "scope":"'${AUTH_SCOPE}'",
        "aud":"'${TOKEN_URI}'",
        "exp":'$(( $(date +%s) + 3600 ))',
        "iat":'$(date +%s)'
    }'
    
    print_status "Creating base64_jwt_header..."
    base64_jwt_header=$(printf '%s' "${jwt_header}" | base64 | tr '+/' '-_')
    print_status "Creating base64_jwt_claim_set..."
    base64_jwt_claim_set=$(printf '%s' "${jwt_claim_set}" | base64 | tr '+/' '-_')
    
    print_status "Creating base64_signature..."
    base64_signature=$(printf '%s' "${base64_jwt_header}.${base64_jwt_claim_set}" | openssl dgst -sha256 -sign "${private_key_path}" | base64 | tr '+/' '-_')
    print_status "Creating JWT_TOKEN..."
    JWT_TOKEN="${base64_jwt_header}.${base64_jwt_claim_set}.${base64_signature}"
    
    print_info "JWT token configured!"
    print_info "${JWT_TOKEN}"
}

#######################################
# Authorize google api
# Globals:
#   JWT_TOKEN
#   TOKEN_URI
#   ACCESS_TOKEN
# Arguments:
#   None
#######################################
function authorize_google () {
    print_status "Requesting access_token..."
    response=$(
        curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${JWT_TOKEN}" \
        "${TOKEN_URI}"
    )
    
    print_response "${response}"
    
    ACCESS_TOKEN=$(printf "%s" "${response}" | jq -r '.access_token')
    
    check_curl "${ACCESS_TOKEN}"
    
    print_info "ACCESS_TOKEN received!"
    print_info "${ACCESS_TOKEN}"
}

function main() {
    install_dependencies
    generate_jwt
    authorize_google
}

main