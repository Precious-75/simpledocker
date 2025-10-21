#!/bin/bash

# exit codes
EXIT_SUCCESS=0
EXIT_GIT_FAILED=10
EXIT_SSH_FAILED=20
EXIT_DOCKER_FAILED=30
EXIT_NGINX_FAILED=40
EXIT_VALIDATION_FAILED=50
EXIT_TRANSFER_FAILED=60

# logging setup
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup_on_error() {
    log "ERROR: Script failed at line $1"
    log "Deployment failed. Check $LOG_FILE for details"
    exit 1
}

trap 'cleanup_on_error $LINENO' ERR
set -e

# cleanup flag
if [ "$1" = "--cleanup" ]; then
    log "cleanup mode"
    
    read -p "Enter SSH Username: " SSH_USERNAME
    read -p "Enter Server IP Address: " SERVER_IP
    read -p "Enter SSH Key Path: " SSH_KEY_PATH
    
    log "connecting to server..."
    
    ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" bash << 'ENDSSH'
        echo "stopping containers..."
        docker stop myapp 2>/dev/null || true
        docker rm myapp 2>/dev/null || true
        docker-compose down 2>/dev/null || true
        
        echo "removing images..."
        docker rmi myapp 2>/dev/null || true
        
        # cleanup networks too
        echo "cleaning networks..."
        docker network rm myapp_network 2>/dev/null || true
        
        echo "removing nginx stuff..."
        sudo rm -f /etc/nginx/sites-enabled/myapp
        sudo rm -f /etc/nginx/sites-available/myapp
        sudo systemctl reload nginx 2>/dev/null || true
        
        echo "removing app dir..."
        rm -rf /home/$USER/app
        
        echo "done"
ENDSSH
    
    log "cleanup done"
    exit $EXIT_SUCCESS
fi

log "Bash Script"

read -p "Enter Git Repository URL: " GIT_REPO_URL
read -sp "Enter Personal Access Token (PAT): " PAT
echo ""
read -p "Enter Branch name (default: main): " BRANCH_NAME
BRANCH_NAME=${BRANCH_NAME:-main}

read -p "Enter SSH Username: " SSH_USERNAME
read -p "Enter Server IP Address: " SERVER_IP
read -p "Enter SSH Key Path: " SSH_KEY_PATH
read -p "Enter Application Port: " APP_PORT

echo ""
log "config collected, starting deployment"
echo ""

log "cloning repo"

REPO_NAME=$(basename "$GIT_REPO_URL" .git)

# check if repo already exists
if [ -d "$REPO_NAME" ]; then
    log "repo exists, pulling changes"
    cd "$REPO_NAME" || exit $EXIT_GIT_FAILED
    git pull origin "$BRANCH_NAME" || exit $EXIT_GIT_FAILED
else
    log "cloning..."
    git clone "https://${PAT}@${GIT_REPO_URL#https://}" || exit $EXIT_GIT_FAILED
    cd "$REPO_NAME" || exit $EXIT_GIT_FAILED
    git checkout "$BRANCH_NAME" || exit $EXIT_GIT_FAILED
fi

log "repo ready"
echo ""


log "checking for dockerfile"

if [ -f "Dockerfile" ]; then
    log "found Dockerfile"
elif [ -f "docker-compose.yml" ]; then
    log "found docker-compose.yml"
else
    log "ERROR: no Dockerfile or docker-compose.yml"
    exit $EXIT_GIT_FAILED
fi

echo ""

log "testing ssh"

ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 "$SSH_USERNAME@$SERVER_IP" "echo 'SSH connection successful'" || {
    log "ERROR: ssh failed"
    exit $EXIT_SSH_FAILED
}

echo ""

log "setting up remote server"

ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" bash << 'ENDSSH'
    echo "updating packages..."
    sudo apt update -y
    
    # install docker if needed
    echo "checking docker..."
    if ! command -v docker &> /dev/null; then
        sudo apt install -y docker.io
    fi
    
    # docker compose
    echo "checking docker-compose..."
    if ! command -v docker-compose &> /dev/null; then
        sudo apt install -y docker-compose
    fi
    
    # nginx
    echo "checking nginx..."
    if ! command -v nginx &> /dev/null; then
        sudo apt install -y nginx
    fi
    
    echo "adding user to docker group"
    sudo usermod -aG docker $USER
    
    # start services
    echo "starting docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    echo "starting nginx..."
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
    # verify everything installed
    docker --version
    docker-compose --version
    nginx -v
    
    echo "server ready"
ENDSSH

echo ""


log "deploying app"

REMOTE_DIR="/home/$SSH_USERNAME/app"

ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" "mkdir -p $REMOTE_DIR"

log "transferring files"

# had to use tar instead of rsync
tar czf - --exclude='.git' . | ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" "cd $REMOTE_DIR && tar xzf -"

if [ $? -ne 0 ]; then
    log "ERROR: transfer failed"
    exit $EXIT_TRANSFER_FAILED
fi

log "files transferred"

ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" bash << ENDSSH
    cd $REMOTE_DIR
    
    # stop old stuff
    echo "stopping old containers..."
    docker stop myapp 2>/dev/null || true
    docker rm myapp 2>/dev/null || true
    docker-compose down 2>/dev/null || true
    
    echo "removing old images..."
    docker rmi myapp 2>/dev/null || true
    
    # cleanup old networks
    docker network prune -f 2>/dev/null || true
    
    echo "building..."
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d --build --force-recreate
        BUILD_STATUS=\$?
    else
        docker build -t myapp .
        BUILD_STATUS=\$?
        
        if [ \$BUILD_STATUS -eq 0 ]; then
            docker run -d --name myapp -p $APP_PORT:$APP_PORT --restart unless-stopped myapp
        fi
    fi
    
    if [ \$BUILD_STATUS -ne 0 ]; then
        echo "ERROR: build failed"
        exit 1
    fi
    
    # wait for container to start
    echo "waiting..."
    sleep 10
    
    docker ps -a
    
    echo ""
    echo "logs:"
    if [ -f "docker-compose.yml" ]; then
        docker-compose logs --tail=50
    else
        docker logs myapp --tail=50 2>&1 || echo "no logs"
    fi
ENDSSH

if [ $? -ne 0 ]; then
    log "ERROR: deployment failed"
    exit $EXIT_DOCKER_FAILED
fi

echo ""

log "setting up nginx"

ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" bash << ENDSSH
    echo "creating nginx config..."
    sudo tee /etc/nginx/sites-available/myapp > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    echo "enabling config..."
    sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # test config
    sudo nginx -t
    
    sudo systemctl reload nginx
    
    echo "nginx done"
ENDSSH

if [ $? -ne 0 ]; then
    log "ERROR: nginx setup failed"
    exit $EXIT_NGINX_FAILED
fi

echo ""

log "validating everything"

ssh -i "$SSH_KEY_PATH" "$SSH_USERNAME@$SERVER_IP" bash << ENDSSH
    # check docker
    echo "checking docker service..."
    if sudo systemctl is-active --quiet docker; then
        echo "docker running"
    else
        echo "ERROR: docker not running"
        exit 1
    fi
    
    echo ""
    # check container
    echo "checking container..."
    CONTAINER_RUNNING=\$(docker ps --filter "name=myapp" --filter "status=running" -q)
    
    if [ -z "\$CONTAINER_RUNNING" ]; then
        echo "ERROR: container not running"
        docker ps -a
        exit 1
    else
        echo "container running"
    fi
    
    echo ""
    # check nginx
    echo "checking nginx..."
    if sudo systemctl is-active --quiet nginx; then
        echo "nginx running"
    else
        echo "ERROR: nginx not running"
        exit 1
    fi
    
    echo ""
    # test app
    echo "testing app..."
    sleep 5
    if curl -f -s http://localhost:$APP_PORT > /dev/null 2>&1; then
        echo "app responding on port $APP_PORT"
    else
        echo "ERROR: app not responding"
        sudo ss -tlnp | grep $APP_PORT || echo "port not listening"
        exit 1
    fi
    
    echo ""
    echo "validation passed"
ENDSSH

if [ $? -ne 0 ]; then
    log "validation failed"
    exit $EXIT_VALIDATION_FAILED
fi

echo ""
log "testing external access"
sleep 3

if curl -f -s "http://$SERVER_IP" > /dev/null 2>&1; then
    log "external access works!"
else
    log "WARNING: external access failed"
    log "might need to check firewall settings"
    log "try manually: http://$SERVER_IP"
fi

echo ""
log "DONE!"
log "app accessible at: http://$SERVER_IP"
log "log file: $LOG_FILE"
echo ""

exit $EXIT_SUCCESS
