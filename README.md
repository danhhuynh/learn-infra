# Node.js MySQL App - AWS Deployment Guide

## 🏗️ Project Overview

This is a comprehensive Node.js application scaffold with MySQL database, designed for deployment on AWS using Docker containers and GitHub Actions CI/CD pipeline.

### Architecture Components
- **Application**: Node.js with Express.js framework
- **Database**: MySQL (local development) / AWS Aurora (production)
- **Containerization**: Docker with multi-stage builds
- **CI/CD**: GitHub Actions with GHCR (GitHub Container Registry)
- **Deployment**: AWS EC2 with Docker Compose

## 🚀 Quick Start - Local Development

1. **Clone and setup**:
   ```bash
   git clone <your-repo>
   cd <your-repo>
   cp .env.example .env
   npm install
   ```

2. **Start local development environment**:
   ```bash
   # Start with Docker (includes MySQL database)
   docker-compose up -d
   
   # Or start just the app (if you have local MySQL)
   npm run dev
   ```

3. **Access the application**:
   - App: http://localhost:3000
   - Health check: http://localhost:3000/health
   - phpMyAdmin: http://localhost:8080 (root/password)

4. **API Endpoints**:
   - `GET /` - API info
   - `GET /health` - Health check
   - `GET /api/users` - List users
   - `POST /api/users` - Create user
   - `GET /api/users/:id` - Get user by ID

## 📋 Required GitHub Secrets

Add these secrets to your GitHub repository (`Settings` > `Secrets and variables` > `Actions`):

### EC2 Connection
- `EC2_HOST` - Your EC2 instance public IP or domain (e.g., `3.15.123.45`)
- `EC2_USER` - EC2 username (usually `ubuntu` for Ubuntu, `ec2-user` for Amazon Linux)
- `EC2_SSH_KEY` - Private SSH key content (the entire content of your `.pem` file)

### Database Configuration
- `DB_HOST` - Aurora cluster endpoint (e.g., `your-aurora-cluster.cluster-xyz.us-east-1.rds.amazonaws.com`)
- `DB_PORT` - Database port (usually `3306`)
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `DB_NAME` - Database name (e.g., `nodeapp`)

### Optional GitHub Token
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions (no need to add manually)

## 🖥️ EC2 Instance Preparation

### 1. Launch EC2 Instance
- **Instance Type**: t3.micro or larger
- **AMI**: Ubuntu 22.04 LTS or Amazon Linux 2023
- **Security Group**: Allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS), and 3000 (App)
- **Key Pair**: Create/use a key pair for SSH access

### 2. Connect to EC2 and Install Dependencies

```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version

# Log out and log back in for group changes to take effect
exit
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 3. Create Application Directory

```bash
# Create app directory
mkdir -p ~/app
cd ~/app

# Test Docker
docker run hello-world
```

### 4. Configure Security Group Rules

Ensure your EC2 Security Group allows:
- Port 22 (SSH) from your IP
- Port 3000 (App) from anywhere (0.0.0.0/0) or specific IPs
- Port 80/443 if using a reverse proxy

## 🗄️ AWS Aurora Database Setup

### 1. Create Aurora Cluster
```bash
# Via AWS CLI (optional)
aws rds create-db-cluster \
    --db-cluster-identifier nodeapp-aurora \
    --engine aurora-mysql \
    --master-username admin \
    --master-user-password YourSecurePassword \
    --vpc-security-group-ids sg-xxxxxxxxx \
    --db-subnet-group-name default
```

### 2. Create Database Instance
```bash
aws rds create-db-instance \
    --db-instance-identifier nodeapp-aurora-instance \
    --db-cluster-identifier nodeapp-aurora \
    --db-instance-class db.t3.small \
    --engine aurora-mysql
```

### 3. Initialize Database Schema
Connect to Aurora and run the SQL from `init.sql`:

```sql
CREATE DATABASE IF NOT EXISTS nodeapp;
USE nodeapp;
-- (rest of init.sql content)
```

## 🔧 Environment Configuration

### Local Development (.env)
```bash
NODE_ENV=development
PORT=3000
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=password
DB_NAME=nodeapp
```

### Production (GitHub Secrets)
```bash
NODE_ENV=production
DB_HOST=your-aurora-cluster.cluster-xyz.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=your-secure-password
DB_NAME=nodeapp
```

## 🚀 Deployment Workflow

### Automatic Deployment
1. Push code to `main` branch
2. GitHub Actions automatically:
   - Builds Docker image
   - Pushes to GitHub Container Registry
   - SSHs into EC2
   - Pulls latest image
   - Restarts application

### Manual Deployment
```bash
# On EC2 instance
cd ~/app

# Pull latest changes
docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull

# Restart services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f
```

## 🔍 Monitoring and Troubleshooting

### Check Application Health
```bash
# Health check endpoint
curl http://your-ec2-ip:3000/health

# Check logs
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f app

# Check container status
docker ps
```

### Common Issues

1. **Database Connection Issues**:
   - Verify Aurora security groups allow EC2 access
   - Check database credentials in GitHub secrets
   - Ensure Aurora is in the same VPC as EC2

2. **SSH Connection Issues**:
   - Verify EC2 security group allows SSH (port 22)
   - Check SSH key format in GitHub secrets
   - Ensure EC2_HOST and EC2_USER are correct

3. **Docker Issues**:
   - Ensure Docker daemon is running: `sudo systemctl status docker`
   - Check disk space: `df -h`
   - Clean up old images: `docker image prune -f`

## 📊 Production Best Practices

### Security
- Use IAM roles instead of hardcoded credentials when possible
- Regularly rotate database passwords
- Keep EC2 and Docker updated
- Use HTTPS with SSL certificates
- Implement proper logging and monitoring

### Performance
- Use Aurora read replicas for read-heavy workloads
- Implement application caching (Redis)
- Use CloudWatch for monitoring
- Set up auto-scaling groups for high availability

### Backup
- Enable Aurora automated backups
- Regular database snapshots
- Version control all infrastructure as code

## 🔗 Additional Resources

- [Docker Compose Override Documentation](https://docs.docker.com/compose/extends/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Aurora Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review application logs
3. Verify all GitHub secrets are configured correctly
4. Ensure EC2 and Aurora are properly configured