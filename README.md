# Docker Webhook-Go with R10K

This Docker image combines [webhook-go](https://github.com/voxpupuli/webhook-go) and [r10k](https://github.com/puppetlabs/r10k) for automated Puppet environment deployment via Git webhooks.

## Description

This image provides a ready-to-use webhook server that listens for Git repository changes and automatically deploys Puppet environments using r10k. It's designed for Puppet infrastructure automation, allowing seamless deployment of Puppet code changes from version control.

## Features

- 🔗 **webhook-go**: HTTP webhook server for Git events
- 🚀 **r10k**: Puppet environment deployment tool
- 🐳 **Lightweight**: Based on official Vox Pupuli images
- 📦 **No bundled data**: Requires volume mounts for configuration and environments

## Quick Start

### Using Docker Run

```bash
docker run -d \
  -p 4000:4000 \
  -v /path/to/puppet/environments:/etc/puppetlabs/code/environments \
  -v /path/to/webhook.yml:/etc/voxpupuli/webhook.yml:ro \
  docker-webhook-go:latest
```

### Using Docker Compose

```yaml
version: '3.8'

services:
  webhook-go:
    image: docker-webhook-go:latest
    ports:
      - "4000:4000"
    volumes:
      - /etc/puppetlabs/code/environments:/etc/puppetlabs/code/environments
      - ./webhook.yml:/etc/voxpupuli/webhook.yml:ro
    restart: unless-stopped
```

## Required Volumes

This image **does not include** any configuration or environment data. You must mount the following:

### 1. Puppet Environments Directory

**Path**: `/etc/puppetlabs/code/environments`

This directory will contain your Puppet environments deployed by r10k.

```yaml
volumes:
  - /etc/puppetlabs/code/environments:/etc/puppetlabs/code/environments
```

**Note**: Ensure the container has write permissions to this directory.

### 2. Webhook Configuration

**Path**: `/etc/voxpupuli/webhook.yml`

Configuration file for webhook-go. See [Configuration](#configuration) section below.

```yaml
volumes:
  - ./webhook.yml:/etc/voxpupuli/webhook.yml:ro
```

## Configuration

### Minimal webhook.yml Example

```yaml
# /etc/voxpupuli/webhook.yml
server:
  port: 4000
  bind: "0.0.0.0"

webhooks:
  - name: puppet-control
    path: /webhook
    secret: your-webhook-secret
    events:
      - push
    commands:
      - /usr/local/bin/r10k deploy environment -p
```

### Complete webhook.yml Example

```yaml
# /etc/voxpupuli/webhook.yml
server:
  port: 4000
  bind: "0.0.0.0"

logging:
  level: info
  format: json

webhooks:
  - name: puppet-control-repo
    path: /webhook/puppet
    secret: your-secret-token-here
    events:
      - push
      - tag_push
    branches:
      - production
      - development
    commands:
      - /usr/local/bin/r10k deploy environment -p -v

  - name: puppet-control-full
    path: /webhook/puppet-full
    secret: another-secret-token
    events:
      - push
    commands:
      - /usr/local/bin/r10k deploy environment -pv
      - echo "Deployment completed at $(date)"
```

### R10K Configuration

If you need a custom r10k configuration, mount it to `/etc/puppetlabs/r10k/r10k.yaml`:

```yaml
# r10k.yaml
cachedir: '/var/cache/r10k'
sources:
  puppet:
    remote: 'https://github.com/your-org/puppet-control.git'
    basedir: '/etc/puppetlabs/code/environments'
git:
  private_key: '/etc/puppetlabs/puppet/ssh/id_rsa'
```

Mount it in your compose file:

```yaml
volumes:
  - ./r10k.yaml:/etc/puppetlabs/r10k/r10k.yaml:ro
  - ./ssh-key:/etc/puppetlabs/puppet/ssh/id_rsa:ro
```

## Usage

### 1. Prepare Configuration

Create your `webhook.yml`:

```bash
cat > webhook.yml <<EOF
server:
  port: 4000
  bind: "0.0.0.0"

webhooks:
  - name: puppet-deploy
    path: /webhook
    secret: ${WEBHOOK_SECRET}
    events:
      - push
    commands:
      - /usr/local/bin/r10k deploy environment -pv
EOF
```

### 2. Create Environments Directory

```bash
mkdir -p /etc/puppetlabs/code/environments
chmod 755 /etc/puppetlabs/code/environments
```

### 3. Start Container

```bash
docker-compose up -d
```

### 4. Configure Git Repository

Add the webhook URL to your Git repository (GitHub, GitLab, Gitea, etc.):

**Webhook URL**: `http://your-server:4000/webhook`
**Secret**: (the secret from your webhook.yml)
**Events**: Push events

### 5. Test Webhook

```bash
# Manual test
curl -X POST http://localhost:4000/webhook \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature: sha1=YOUR_SIGNATURE" \
  -d '{"ref":"refs/heads/production"}'
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| None | Configuration is file-based via mounted volumes | - |

All configuration is done through the mounted `webhook.yml` file.

## Exposed Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 4000 | TCP | Webhook HTTP server |

## Logs

View webhook and r10k logs:

```bash
# Follow logs
docker-compose logs -f webhook-go

# View last 100 lines
docker-compose logs --tail=100 webhook-go
```

## Security Considerations

### 1. Webhook Secrets

Always use strong, randomly generated secrets:

```bash
# Generate a secure secret
openssl rand -hex 32
```

### 2. SSH Keys for Private Repositories

If using private Git repositories, mount SSH keys:

```yaml
volumes:
  - ~/.ssh/id_rsa:/root/.ssh/id_rsa:ro
  - ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro
```

**Important**: Set proper permissions on SSH keys (0600).

### 3. Network Security

- Use HTTPS/TLS in production (reverse proxy recommended)
- Restrict webhook endpoint access via firewall rules
- Use GitHub/GitLab IP allowlists when possible

### 4. File Permissions

Ensure the container has appropriate permissions:

```bash
# Set ownership for environments directory
chown -R 999:999 /etc/puppetlabs/code/environments
```

## Troubleshooting

### Webhook Not Triggering

1. Check webhook configuration in your Git repository
2. Verify the secret matches between Git and webhook.yml
3. Check container logs: `docker-compose logs webhook-go`
4. Test with curl to isolate the issue

### R10K Deployment Fails

1. Verify Git repository access (SSH keys, credentials)
2. Check r10k configuration: `docker exec webhook-go r10k deploy display`
3. Ensure write permissions on environments directory
4. Check r10k logs in container output

### Permission Denied

```bash
# Check directory permissions
ls -la /etc/puppetlabs/code/environments

# Fix permissions
sudo chown -R $(id -u):$(id -g) /etc/puppetlabs/code/environments
```

## Examples

### GitHub Integration

```yaml
# webhook.yml for GitHub
webhooks:
  - name: github-puppet
    path: /webhook/github
    secret: github-webhook-secret
    events:
      - push
    headers:
      X-GitHub-Event: push
    commands:
      - /usr/local/bin/r10k deploy environment -pv
```

### GitLab Integration

```yaml
# webhook.yml for GitLab
webhooks:
  - name: gitlab-puppet
    path: /webhook/gitlab
    secret: gitlab-webhook-secret
    events:
      - push
    headers:
      X-Gitlab-Event: Push Hook
    commands:
      - /usr/local/bin/r10k deploy environment -pv
```

### Multiple Environments

```yaml
# webhook.yml for branch-specific deployments
webhooks:
  - name: production
    path: /webhook/production
    secret: prod-secret
    events:
      - push
    branches:
      - production
    commands:
      - /usr/local/bin/r10k deploy environment production -pv

  - name: development
    path: /webhook/development
    secret: dev-secret
    events:
      - push
    branches:
      - development
      - feature/*
    commands:
      - /usr/local/bin/r10k deploy environment development -pv
```

## References

- [webhook-go Documentation](https://github.com/voxpupuli/webhook-go)
- [r10k Documentation](https://github.com/puppetlabs/r10k)
- [Puppet Environments](https://puppet.com/docs/puppet/latest/environments_about.html)

## License

This project is provided as-is for personal and educational use.

## Contributing

Contributions are welcome! Please submit issues and pull requests on the project repository.
