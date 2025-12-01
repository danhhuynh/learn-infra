# GitHub Repository Secrets Configuration Guide

## Required Secrets for GitHub Actions

Add these secrets in your GitHub repository: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

### 🖥️ EC2 Connection Secrets

#### `EC2_HOST`
- **Description**: Public IP address or domain of your EC2 instance
- **Example**: `3.15.123.45` or `my-app.example.com`
- **How to get**: Check your EC2 instance details in AWS Console

#### `EC2_USER`
- **Description**: Username for SSH connection to EC2
- **Values**:
  - Ubuntu instances: `ubuntu`
  - Amazon Linux: `ec2-user`
  - CentOS: `centos`
  - Debian: `admin`

#### `EC2_SSH_KEY`
- **Description**: Private SSH key content for EC2 access
- **Format**: The entire content of your `.pem` key file
- **Example**:
  ```
  -----BEGIN RSA PRIVATE KEY-----
  MIIEowIBAAKCAQEA... (your full private key content)
  -----END RSA PRIVATE KEY-----
  ```
- **How to get**: 
  1. Download your `.pem` file when creating EC2 instance
  2. Copy entire file content (including BEGIN/END lines)
  3. Paste as secret value

### 🗄️ Database Configuration Secrets

#### `DB_HOST`
- **Description**: Aurora cluster endpoint
- **Example**: `my-aurora-cluster.cluster-abc123.us-east-1.rds.amazonaws.com`
- **How to get**: AWS RDS Console → Aurora cluster → Connectivity & security → Endpoint

#### `DB_PORT`
- **Description**: Database port
- **Value**: `3306` (default for MySQL)

#### `DB_USER`
- **Description**: Database username
- **Example**: `admin` or `nodeapp_user`

#### `DB_PASSWORD`
- **Description**: Database password
- **Security**: Use a strong, unique password
- **Example**: `MySecurePassword123!`

#### `DB_NAME`
- **Description**: Database name
- **Value**: `nodeapp` (or your preferred database name)

## 🔒 Security Best Practices

### SSH Key Security
- ✅ Use unique SSH keys per environment
- ✅ Regularly rotate SSH keys
- ✅ Never commit SSH keys to version control
- ✅ Use minimum required permissions

### Database Security
- ✅ Use strong, unique passwords
- ✅ Enable Aurora encryption at rest
- ✅ Use IAM database authentication when possible
- ✅ Restrict database access to EC2 security groups only

### AWS IAM Roles (Advanced)
Instead of storing credentials as secrets, consider using IAM roles:

```yaml
# In your GitHub Actions workflow
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    aws-region: us-east-1
```

## 🧪 Testing Secrets Configuration

### Test SSH Connection
```bash
# Test SSH connection manually
ssh -i your-key.pem ubuntu@your-ec2-ip

# Test from GitHub Actions (in your workflow)
ssh -o StrictHostKeyChecking=no ubuntu@${{ secrets.EC2_HOST }} "echo 'SSH connection successful'"
```

### Test Database Connection
```bash
# From EC2 instance
mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SELECT 1"
```

## 🔍 Troubleshooting Common Issues

### SSH Key Issues
- ❌ **Error**: `Permission denied (publickey)`
- ✅ **Solution**: 
  - Verify EC2_SSH_KEY contains the complete private key
  - Check EC2_USER matches your instance type
  - Ensure EC2 security group allows SSH (port 22)

### Database Connection Issues
- ❌ **Error**: `ECONNREFUSED` or timeout
- ✅ **Solution**:
  - Verify Aurora security group allows access from EC2
  - Check DB_HOST endpoint is correct
  - Ensure Aurora cluster is running

### GitHub Actions Permission Issues
- ❌ **Error**: `403 Forbidden` when pushing to GHCR
- ✅ **Solution**:
  - Repository must have package write permissions
  - Check repository visibility settings
  - Verify GITHUB_TOKEN has proper scopes

## 📋 Secrets Checklist

Before triggering deployment, ensure you have configured:

- [ ] `EC2_HOST` - EC2 instance IP/domain
- [ ] `EC2_USER` - SSH username for EC2
- [ ] `EC2_SSH_KEY` - Complete private SSH key content
- [ ] `DB_HOST` - Aurora cluster endpoint
- [ ] `DB_PORT` - Database port (usually 3306)
- [ ] `DB_USER` - Database username
- [ ] `DB_PASSWORD` - Database password
- [ ] `DB_NAME` - Database name

## 🔄 Rotating Secrets

### SSH Key Rotation
1. Generate new SSH key pair
2. Add public key to EC2 instance (`~/.ssh/authorized_keys`)
3. Update `EC2_SSH_KEY` secret in GitHub
4. Remove old public key from EC2

### Database Password Rotation
1. Update password in Aurora
2. Update `DB_PASSWORD` secret in GitHub
3. Redeploy application

## 🆘 Emergency Access

If GitHub Actions deployment fails, you can always deploy manually:

```bash
# SSH into EC2
ssh -i your-key.pem ubuntu@your-ec2-ip

# Navigate to app directory
cd ~/app

# Manual deployment
./deploy.sh
```