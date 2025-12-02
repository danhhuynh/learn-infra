# EC2 Instance Setup Script
# Run this script on your EC2 instance to prepare it for deployment

#!/bin/bash

set -e

echo "🚀 Setting up EC2 instance for Node.js app deployment..."

# Detect OS and set package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION_ID=$VERSION_ID
fi

# Determine package manager and commands
if [[ "$OS" == *"Amazon Linux"* ]]; then
    PKG_MANAGER="yum"
    UPDATE_CMD="sudo yum update -y"
    INSTALL_CMD="sudo yum install -y"
    USER_HOME="/home/ec2-user"
    SERVICE_USER="ec2-user"
    echo "📋 Detected: Amazon Linux"
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    PKG_MANAGER="apt"
    UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
    INSTALL_CMD="sudo apt install -y"
    USER_HOME="/home/ubuntu"
    SERVICE_USER="ubuntu"
    echo "📋 Detected: $OS"
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    PKG_MANAGER="yum"
    UPDATE_CMD="sudo yum update -y"
    INSTALL_CMD="sudo yum install -y"
    USER_HOME="/home/centos"
    SERVICE_USER="centos"
    echo "📋 Detected: $OS"
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

# Update system packages
echo "📦 Updating system packages..."
eval $UPDATE_CMD

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    if [[ "$PKG_MANAGER" == "yum" ]]; then
        # Amazon Linux / CentOS / RHEL
        $INSTALL_CMD docker
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        # Ubuntu / Debian - use official Docker script
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    fi
    sudo usermod -aG docker $USER
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose
echo "🔧 Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already installed"
fi

# Create application directory
echo "📁 Creating application directory..."
mkdir -p ~/app
cd ~/app

# Create systemd service for auto-start (optional)
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/nodeapp.service > /dev/null << EOF
[Unit]
Description=Node.js MySQL App
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$USER_HOME/app
ExecStart=/usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
User=$SERVICE_USER
Group=$SERVICE_USER

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable nodeapp.service

# Install useful monitoring tools
echo "📊 Installing monitoring tools..."
if [[ "$PKG_MANAGER" == "yum" ]]; then
    # Amazon Linux specific - handle curl conflict and skip packages that are already available
    echo "Installing tools for Amazon Linux..."
    $INSTALL_CMD htop git 2>/dev/null || echo "Some packages may already be installed"
    # curl and wget are usually pre-installed on Amazon Linux, skip if conflict
    if ! command -v curl &> /dev/null; then
        $INSTALL_CMD curl || echo "curl installation skipped due to conflicts"
    fi
    if ! command -v wget &> /dev/null; then
        $INSTALL_CMD wget || echo "wget installation skipped - may already be installed"
    fi
else
    $INSTALL_CMD htop curl wget git
fi

# Configure log rotation for Docker
echo "📝 Configuring log rotation..."
sudo tee /etc/logrotate.d/docker > /dev/null << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF

# Create a deployment script
echo "📝 Creating deployment script..."
cat > ~/app/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting deployment..."

# Navigate to app directory
cd ~/app

# Check if required files exist
if [ ! -f "docker-compose.yml" ] || [ ! -f "docker-compose.prod.yml" ] || [ ! -f ".env" ]; then
    echo "❌ Required files missing. Please ensure docker-compose files and .env are present."
    exit 1
fi

# Pull the latest images
echo "📥 Pulling latest images..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down

# Start new containers
echo "▶️ Starting new containers..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -f

# Wait for application to be ready
echo "⏳ Waiting for application to be ready..."
sleep 30

# Health check
echo "🏥 Performing health check..."
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Deployment successful! Application is healthy."
else
    echo "❌ Health check failed. Check logs:"
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=50
    exit 1
fi

# Show container status
echo "📊 Container status:"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
EOF

chmod +x ~/app/deploy.sh

# Show versions
echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📋 Installed versions:"
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo ""
echo "📁 Application directory: ~/app"
echo "🚀 Deployment script: ~/app/deploy.sh"
echo ""
echo "⚠️  Important: Please log out and log back in for Docker group changes to take effect."
echo ""
echo "🔧 Next steps:"
echo "1. Configure your GitHub repository secrets"
echo "2. Set up your Aurora database"
echo "3. Push code to main branch to trigger deployment"
echo ""
echo "💡 Manual deployment: cd ~/app && ./deploy.sh"
EOF