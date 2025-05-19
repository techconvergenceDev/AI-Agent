#!/bin/bash

USE_GPU=0
PORT=3000
DOMAIN=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --gpu) USE_GPU=1 ;;
        --port) PORT="$2"; shift ;;
        --domain) DOMAIN="$2"; shift ;;
        *) exit 1 ;;
    esac
    shift
done

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[ "$(id -u)" -ne 0 ] && error "This script must be run as root or with sudo"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
    info "Detected OS: $OS $VERSION"
else
    error "Cannot detect operating system"
fi

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)

info "Available memory: $TOTAL_MEM MB"
info "CPU cores: $CPU_CORES"

if [ "$TOTAL_MEM" -lt 7500 ]; then
    warn "Low memory detected: $TOTAL_MEM MB."
    read -p "Continue anyway? (y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

if [ "$CPU_CORES" -lt 4 ]; then
    warn "Low CPU core count: $CPU_CORES."
    read -p "Continue anyway? (y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    warn "Port $PORT is already in use."
    read -p "Use different port? (y/n) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && read -p "Enter new port number: " PORT
fi

install_docker() {
    info "Installing Docker..."
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$(echo $ID | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(echo $ID | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        error "Unsupported OS"
    fi
    systemctl start docker
    systemctl enable docker
    docker --version && info "Docker installed" || error "Docker installation failed"
}

command -v docker &> /dev/null || install_docker

if [ "$USE_GPU" -eq 1 ]; then
    if lspci | grep -i nvidia &> /dev/null; then
        info "NVIDIA GPU detected"
        if ! command -v nvidia-smi &> /dev/null; then
            warn "Installing NVIDIA drivers..."
            if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
                apt update
                apt install -y nvidia-driver-535 nvidia-utils-535
            elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
                dnf config-manager --add-repo=https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
                dnf install -y nvidia-driver-latest-dkms
            fi
        fi
        info "Installing NVIDIA Container Toolkit..."
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
            curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | apt-key add -
            curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | tee /etc/apt/sources.list.d/libnvidia-container.list
            apt update
            apt install -y nvidia-docker2
        elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
            distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
            curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
            yum install -y nvidia-container-toolkit
        fi
        systemctl restart docker
        nvidia-smi &> /dev/null && info "GPU ready" || warn "GPU setup incomplete"
    else
        warn "No GPU detected. Continuing without GPU."
        USE_GPU=0
    fi
fi

docker ps -a | grep -q "open-webui" && {
    warn "Container exists"
    read -p "Remove? (y/n) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && docker stop open-webui && docker rm open-webui || error "Please remove manually"
}

info "Starting container..."
if [ "$USE_GPU" -eq 1 ]; then
    docker run -d --name open-webui --gpus all -p $PORT:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:ollama
else
    docker run -d --name open-webui -p $PORT:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:ollama
fi

docker ps | grep -q "open-webui" || error "Container failed"

if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    command -v ufw &> /dev/null && ufw allow $PORT/tcp && ufw status || warn "UFW not found"
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    command -v firewall-cmd &> /dev/null && firewall-cmd --permanent --add-port=$PORT/tcp && firewall-cmd --reload || warn "firewalld not found"
fi

if [ -n "$DOMAIN" ]; then
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update
        apt install -y nginx certbot python3-certbot-nginx
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum install -y epel-release
        yum install -y nginx certbot python3-certbot-nginx
    fi
    cat > /etc/nginx/sites-available/open-webui.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    ln -s /etc/nginx/sites-available/open-webui.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
fi

cat > /usr/local/bin/ollama-manager << EOF
#!/bin/bash
case "\$1" in
    start) docker start open-webui ;;
    stop) docker stop open-webui ;;
    restart) docker restart open-webui ;;
    status) docker ps | grep -q "open-webui" && echo "running" || echo "stopped" ;;
    logs) docker logs open-webui ;;
    pull-model) docker exec -it open-webui ollama pull \$2 ;;
    update)
        docker pull ghcr.io/open-webui/open-webui:ollama
        docker stop open-webui
        docker rm open-webui
        [ "$USE_GPU" -eq 1 ] && docker run -d --name open-webui --gpus all -p $PORT:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:ollama || docker run -d --name open-webui -p $PORT:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:ollama
        ;;
    backup)
        backup_dir="\$HOME/ollama-backups/\$(date +%Y%m%d)"
        mkdir -p \$backup_dir
        docker run --rm -v ollama:/data -v \$backup_dir:/backup alpine tar -czf /backup/ollama.tar.gz -C /data .
        docker run --rm -v open-webui:/data -v \$backup_dir:/backup alpine tar -czf /backup/open-webui.tar.gz -C /data .
        ;;
    *) echo "Usage: ollama-manager {start|stop|restart|status|logs|pull-model|update|backup}" ;;
esac
EOF

chmod +x /usr/local/bin/ollama-manager

SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}Installation Complete!${NC}"
[ -n "$DOMAIN" ] && echo "Web interface: https://$DOMAIN" || echo "Web interface: http://$SERVER_IP:$PORT"
echo
echo "To manage, use: ollama-manager start|stop|restart|status|logs|pull-model|update|backup"

echo -e "\nCreated by Sunil Kumar"
echo "web: https://techconvergence.dev"
