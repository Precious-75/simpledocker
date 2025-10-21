#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Docker Deployment Script ===${NC}\n"

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Prompt user for inputs
echo "Step 1: Repository Information"
echo "--------------------------------"
read -p "Enter Git Repository URL: " REPO_URL
while [ -z "$REPO_URL" ]; do
    echo -e "${RED}Error: Repository URL cannot be empty${NC}"
    read -p "Enter Git Repository URL: " REPO_URL
done

read -sp "Enter Personal Access Token (PAT): " PAT
echo
while [ -z "$PAT" ]; do
    echo -e "${RED}Error: PAT cannot be empty${NC}"
    read -sp "Enter Personal Access Token (PAT): " PAT
    echo
done

read -p "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

echo -e "\n${GREEN}Step 2: SSH Connection Details${NC}"
echo "--------------------------------"
read -p "Enter SSH username: " SSH_USER
while [ -z "$SSH_USER" ]; do
    echo -e "${RED}Error: SSH username cannot be empty${NC}"
    read -p "Enter SSH username: " SSH_USER
done

read -p "Enter server IP: " SERVER_IP
while [ -z "$SERVER_IP" ] || ! validate_ip "$SERVER_IP"; do
    echo -e "${RED}Error: Invalid IP address format${NC}"
    read -p "Enter server IP: " SERVER_IP
done

read -p "Enter SSH key path (e.g., ~/.ssh/id_rsa): " SSH_KEY
while [ -z "$SSH_KEY" ] || [ ! -f "$SSH_KEY" ]; do
    if [ -z "$SSH_KEY" ]; then
        echo -e "${RED}Error: SSH key path cannot be empty${NC}"
    else
        echo -e "${RED}Error: SSH key file not found at: $SSH_KEY${NC}"
    fi
    read -p "Enter SSH key path: " SSH_KEY
done

read -p "Enter application port: " APP_PORT
while [ -z "$APP_PORT" ] || ! validate_port "$APP_PORT"; do
    echo -e "${RED}Error: Invalid port number (1-65535)${NC}"
    read -p "Enter application port: " APP_PORT
done

# Summary of inputs
echo -e "\n${GREEN}=== Configuration Summary ===${NC}"
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo "SSH User: $SSH_USER"
echo "Server IP: $SERVER_IP"
echo "SSH Key: $SSH_KEY"
echo "App Port: $APP_PORT"
echo

read -p "Proceed with deployment? (y/n): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo -e "\n${GREEN}All inputs validated successfully!${NC}"
echo -e "${YELLOW}Ready for Phase 2: Deployment steps...${NC}"

# TODO: Add deployment logic here in next phases#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Docker Deployment Script ===${NC}\n"

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Prompt user for inputs
echo "Step 1: Repository Information"
echo "--------------------------------"
read -p "Enter Git Repository URL: " REPO_URL
while [ -z "$REPO_URL" ]; do
    echo -e "${RED}Error: Repository URL cannot be empty${NC}"
    read -p "Enter Git Repository URL: " REPO_URL
done

read -sp "Enter Personal Access Token (PAT): " PAT
echo
while [ -z "$PAT" ]; do
    echo -e "${RED}Error: PAT cannot be empty${NC}"
    read -sp "Enter Personal Access Token (PAT): " PAT
    echo
done

read -p "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

echo -e "\n${GREEN}Step 2: SSH Connection Details${NC}"
echo "--------------------------------"
read -p "Enter SSH username: " SSH_USER
while [ -z "$SSH_USER" ]; do
    echo -e "${RED}Error: SSH username cannot be empty${NC}"
    read -p "Enter SSH username: " SSH_USER
done

read -p "Enter server IP: " SERVER_IP
while [ -z "$SERVER_IP" ] || ! validate_ip "$SERVER_IP"; do
    echo -e "${RED}Error: Invalid IP address format${NC}"
    read -p "Enter server IP: " SERVER_IP
done

read -p "Enter SSH key path (e.g., ~/.ssh/id_rsa): " SSH_KEY
while [ -z "$SSH_KEY" ] || [ ! -f "$SSH_KEY" ]; do
    if [ -z "$SSH_KEY" ]; then
        echo -e "${RED}Error: SSH key path cannot be empty${NC}"
    else
        echo -e "${RED}Error: SSH key file not found at: $SSH_KEY${NC}"
    fi
    read -p "Enter SSH key path: " SSH_KEY
done

read -p "Enter application port: " APP_PORT
while [ -z "$APP_PORT" ] || ! validate_port "$APP_PORT"; do
    echo -e "${RED}Error: Invalid port number (1-65535)${NC}"
    read -p "Enter application port: " APP_PORT
done

# Summary of inputs
echo -e "\n${GREEN}=== Configuration Summary ===${NC}"
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo "SSH User: $SSH_USER"
echo "Server IP: $SERVER_IP"
echo "SSH Key: $SSH_KEY"
echo "App Port: $APP_PORT"
echo

read -p "Proceed with deployment? (y/n): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo -e "\n${GREEN}All inputs validated successfully!${NC}"
echo -e "${YELLOW}Ready for Phase 2: Deployment steps...${NC}"

# TODO: Add deployment logic here in next phases
