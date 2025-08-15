# SS14.Watchdog 

SS14.Watchdog is SS14's server-hosting wrapper thing, similar to [TGS](https://github.com/tgstation/tgstation-server) for BYOND (but much simpler for the time being). It handles auto updates, monitoring, automatic restarts, and administration. We recommend you use this for proper deployments.

## Quick Setup

For detailed setup instructions, see the [official SS14 documentation](https://docs.spacestation14.io/en/getting-started/hosting#watchdog).

## Docker Setup

This repository includes a complete Docker setup with Traefik reverse proxy support.

### Prerequisites

- Docker and Docker Compose
- A domain name pointed to your server
- Traefik reverse proxy (optional but recommended)
- PostgreSQL database (recommended for production)

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/space-wizards/SS14.Watchdog.git
   cd SS14.Watchdog
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   cp appsettings.yml.example appsettings.yml
   ```

3. **Edit `.env` file:**
   - Set your domain names
   - Configure volume paths
   - Update Traefik settings

4. **Edit `appsettings.yml` file:**
   - Configure database connection
   - Set secure API tokens
   - Configure your SS14 server instances

5. **Build and run:**
   ```bash
   docker-compose up -d --build
   ```

### Configuration Files

#### .env Configuration

```bash
# Application Settings
ASPNETCORE_ENVIRONMENT=Production
# Use 0.0.0.0 to allow Traefik to connect from external networks
ASPNETCORE_URLS=http://0.0.0.0:8080

# Port Configuration
PORT=8080                # Watchdog web interface port
API_PORT=1212           # SS14 game server API port

# Volume Paths (Host Machine)
WATCHDOG_INSTANCES_PATH=/path/to/your/instances
WATCHDOG_APPSETTINGS_PATH=/path/to/your/appsettings.yml

# Traefik Configuration
TRAEFIK_DOMAIN=watchdog.yourdomain.com    # Watchdog web interface
GAME_DOMAIN=server.yourdomain.com         # Game server status endpoint
```

#### appsettings.yml Configuration

Key settings for Docker deployment:

```yaml
# Process Management
Process:
  PersistServers: true
  Mode: "Basic"  # Use Basic mode in Docker (systemd won't work)

# Server Instance
Servers:
  InstanceRoot: "instances/"
  Instances:
    your-server:
      Name: "Your SS14 Server"
      ApiToken: "generate-secure-random-token"  # Use: openssl rand -hex 32
      ApiPort: 1212
      UpdateType: "Manifest"
      Updates:
        ManifestUrl: "https://your-cdn.com/manifest"
      EnvironmentVariables:
        # Database (use public hostname for Docker)
        ROBUST_CVAR_database__engine: "postgres"
        ROBUST_CVAR_database__pg_host: "your-database-host.com"
        # Status endpoint (use your actual domain)
        ROBUST_CVAR_status__connectaddress: "udp://server.yourdomain.com:1212"
        ROBUST_CVAR_hub__server_url: "ss14s://server.yourdomain.com"
```

### Network Architecture

```
Internet → Traefik → SS14 Watchdog Container
                  ↓
              Port 8080: Watchdog Web Interface
              Port 1212: SS14 Game Server (TCP/UDP)
```

### Exposed Services

- **Watchdog Web Interface**: `https://watchdog.yourdomain.com` (via Traefik)
- **Game Server Status**: `https://server.yourdomain.com/status` (via Traefik)
- **Game Server Direct**: `server.yourdomain.com:1212` (TCP/UDP)

### Troubleshooting

#### Database Connection Issues

**Problem**: `Failed to connect to 10.x.x.x:5432` (private IP)
**Solution**: Use the **public** database hostname, not the private one:
```yaml
ROBUST_CVAR_database__pg_host: "your-database-public-host.com"
```

#### Traefik 502 Bad Gateway

**Problem**: Traefik can't connect to the watchdog service
**Solution**: Ensure `ASPNETCORE_URLS=http://0.0.0.0:8080` (not localhost):
```bash
# ❌ Wrong - Traefik can't connect
ASPNETCORE_URLS=http://localhost:8080

# ✅ Correct - Traefik can connect
ASPNETCORE_URLS=http://0.0.0.0:8080
```

#### Watchdog API 400 Bad Request

**Problem**: SS14 server can't ping watchdog internally
**Solution**: This should be resolved automatically with the `0.0.0.0` binding above.

#### Hub Advertising Errors

**Problem**: External hubs can't reach server status
**Solution**: 
1. Ensure port 1212 (TCP/UDP) is open in your firewall
2. Verify your domain points to the correct IP
3. Test status endpoint: `curl https://server.yourdomain.com/status`

### Port Configuration

The setup exposes these ports:

- **1212/tcp**: SS14 server API communication
- **1212/udp**: SS14 game client connections

Port 8080 is **not exposed** externally - Traefik handles external access.

### Security Notes

1. **Generate secure API tokens**: `openssl rand -hex 32`
2. **Use HTTPS**: Configure Traefik with proper SSL certificates
3. **Database credentials**: Store securely, consider using environment variables
4. **Firewall**: Only expose necessary ports (1212 for game traffic)

### Volume Mounts

The container expects these volume mounts:
- `/app/instances`: SS14 server instance data (persistent)
- `/app/appsettings.yml`: Configuration file (read-only)

Ensure the host directories exist and have proper permissions:
```bash
mkdir -p /path/to/instances
chmod 755 /path/to/instances
```

### Health Checks

Verify your setup is working:

```bash
# Test watchdog web interface
curl -I https://watchdog.yourdomain.com/watchdog/padlock

# Test game status endpoint
curl https://server.yourdomain.com/status

# Test API endpoint (should return 405 Method Not Allowed)
curl -I https://watchdog.yourdomain.com/instances/your-server/restart
```

### Development

For development without Traefik, you can expose port 8080 directly:
```yaml
ports:
  - "8080:8080"  # Add this line to docker-compose.yml
  - "1212:1212/tcp"
  - "1212:1212/udp"
```

Then access the watchdog at `http://localhost:8080`.

## Contributing

Please ensure any Docker-related changes are tested with the provided docker-compose setup.

## License

See LICENSE.txt for details.
