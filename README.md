# Ollama + Open WebUI Installer

A powerful Bash script to deploy **Ollama** with **Open WebUI** on any Linux server (Ubuntu, Debian, CentOS, RHEL, etc.). This script automates the full installation and configuration process—including Docker setup, GPU support, firewall configuration, and optional NGINX + SSL setup.

> Created by **Sunil Kumar**  
> 🌐 https://techconvergence.dev

---

## 🚀 Features

- Installs Docker (if missing)
- Optional GPU support with NVIDIA drivers
- Automatically pulls and runs Ollama with Open WebUI in Docker
- Customizable port and domain options
- Sets up UFW or firewalld rules
- NGINX + SSL (Let's Encrypt) integration with domain support
- Management CLI tool: `ollama-manager` for controlling the app
- Backup and model pull functionality

---

## 📦 Prerequisites

- Linux server (Ubuntu/Debian/CentOS/RHEL)
- At least **8GB RAM** and **4 CPU cores** recommended
- Root or sudo privileges
- Internet access
- Optional: NVIDIA GPU for acceleration

---

## 🛠 Installation

### 1. Clone the Repository

git clone https://github.com/techconvergenceDev/AI-Agent.git
cd AI-Agent



2. Make Script Executable

chmod +x ollama-deploy-sunil.sh
3. Run the Installer
Basic usage (default: CPU, port 3000)

sudo ./ollama-deploy-sunil.sh
With GPU and custom port

sudo ./ollama-deploy-sunil.sh --gpu --port 8088
With domain + SSL

sudo ./ollama-deploy-sunil.sh --domain ai.example.com
📋 Usage Instructions
After installation:

Web Interface (no domain):
Visit http://<server-ip>:3000 in your browser

Web Interface (with domain):
Visit https://your-domain.com

⚙️ Management Commands
The script installs a global CLI helper: ollama-manager


ollama-manager start         # Start the container
ollama-manager stop          # Stop the container
ollama-manager restart       # Restart it
ollama-manager status        # Show if it is running
ollama-manager logs          # View container logs
ollama-manager pull-model <model>  # Download a new model inside the container
ollama-manager update        # Pull latest container version
ollama-manager backup        # Backup Ollama and WebUI data
🔐 Domain & SSL (Optional)
To use a custom domain with HTTPS:


sudo ./ollama-deploy-sunil.sh --domain ai.yourdomain.com
The script will:

Install NGINX + Certbot

Configure a reverse proxy

Auto-issue a free Let's Encrypt SSL certificate

🧠 Example Models
Once installed, open the web interface and download one of these:

llama3

gemma:2b

phi3:mini

📂 Backup Location
Backups are saved under:


~/ollama-backups/
Each backup includes:

Ollama model data

Open WebUI config/settings

👨‍💻 Author
Sunil Kumar
🔗 https://techconvergence.dev
