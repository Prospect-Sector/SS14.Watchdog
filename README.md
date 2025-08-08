# PS-SS14.Watchdog 

PS-SS14.Watchdog is SS14's server-hosting wrapper thing, similar to [TGS](https://github.com/tgstation/tgstation-server) for BYOND (but much simpler for the time being). It handles auto updates, monitoring, automatic restarts, and administration. We recommend you use this for proper deployments.

Documentation on how setup and use for SS14.Watchdog is [here](https://docs.spacestation14.io/en/getting-started/hosting#watchdog).

## Docker Deployment

This Docker setup properly replicates the systemctl service functionality by running `SS14.Watchdog.dll` as the main process, equivalent to `ExecStart=/path/to/SS14.Watchdog` in a systemctl service file.

### Prerequisites
- Docker and docker-compose installed
- Traefik reverse proxy running with `traefik_lan` network
- `secure-headers` middleware configured in Traefik

### Quick Start

1. **Clone the repository:**
```bash
git clone https://github.com/dvir001/SS14.Watchdog.git
cd SS14.Watchdog
```

2. **Create required directories:**
```bash
# Create the required directory structure
sudo mkdir -p /root/ss14-watchdog/instances
```

3. **Configure your environment:**
```bash
# Copy the example environment files
cp .env.example .env
cp appsettings.yml.example /root/ss14-watchdog/appsettings.yml

# Edit the Docker Compose configuration
nano .env

# Edit the application configuration
nano /root/ss14-watchdog/appsettings.yml
```

4. **Build and start services:**
```bash
docker-compose up -d --build
```

5. **Access the watchdog:**
The service will be available at: `https://ss14-watchdog.prospect-sector.space`

### Configuration Files

The configuration uses volume-mapped files for easy management:

#### `.env` - Docker Compose Configuration
Contains only essential Docker Compose variables:
- Container names and networks
- Volume paths
- Environment settings

#### `appsettings.yml` - Application Configuration (Volume Mapped)
Contains all SS14.Watchdog application settings:
- Server instance configurations
- Serilog logging settings
- Discord webhook URLs
- API tokens and secrets

**⚠️ SECURITY WARNING**: This file contains sensitive information and should be handled carefully!

### Traefik Configuration

**Important**: Traefik configuration is now managed via environment variables in `.env` for easy customization:
- Domain: Configured via `TRAEFIK_DOMAIN`
- Cert Resolver: Configured via `TRAEFIK_CERT_RESOLVER`
- Middleware: Configured via `TRAEFIK_MIDDLEWARE`
- Network: Configured via `EXTERNAL_NETWORK`

You can customize these settings by editing your `.env` file without modifying docker-compose.yml.

### Environment Configuration

1. **Configure Docker Compose settings:**
   ```bash
   cp .env.example .env
   nano .env
   ```
   - Set `TRAEFIK_DOMAIN` to your domain
   - Adjust volume paths if needed
   - Modify container names if desired
   - Configure port settings

2. **Configure application settings:**
   ```bash
   cp appsettings.yml.example /root/ss14-watchdog/appsettings.yml
   nano /root/ss14-watchdog/appsettings.yml
   ```
   - Keep `BaseUrl` as `http://localhost:5000/` for internal communication
   - Configure server instances with proper API tokens
   - Add Discord webhook URL for notifications

### Docker vs SystemCtl Comparison

**SystemCtl Service:**
```ini
ExecStart=/path/to/SS14.Watchdog
```

**Docker Equivalent:**
```dockerfile
ENTRYPOINT ["dotnet", "SS14.Watchdog.dll"]
```

The Docker setup provides the same functionality as systemctl:
- ✅ **Service Management**: Docker handles process lifecycle (start/stop/restart)
- ✅ **Auto-restart**: `restart: unless-stopped` provides equivalent functionality
- ✅ **Health Monitoring**: Health checks monitor service status
- ✅ **Logging**: Structured logging with `docker logs`
- ✅ **Process Isolation**: Container provides isolation similar to systemd units
- ✅ **SQLite Database**: Uses same database approach as typical systemctl deployments

### Docker Services

The Docker setup includes:
- **PS-SS14-Watchdog**: Main application service running the watchdog with human-readable name
- **Internal Network**: `ps-ss14` network for internal communication
- **External Network**: `traefik_lan` network for external access
- **No PostgreSQL**: Each game server manages its own database (as intended)
- **Traefik Integration**: Configurable via environment variables for reliable SSL and reverse proxy
- **Discord Notifications**: Webhook integration for server events

### Port Configuration

The Docker container uses a dual-port setup for enhanced security and separation:

- **Port 5000 (Internal)**: Server-to-watchdog communication (HTTP) - Used by SS14 game servers to communicate with the watchdog
- **Port 5001 (External)**: Public web interface (HTTPS via Traefik) - Used by administrators to access the watchdog web interface
- **Port 1212**: SS14 game server API communication (for the `prospect-sector-testing` instance)

**Port Flow Architecture**:
```
External Users → Port 5001 (HTTPS) → Traefik → Port 5000 (HTTP) → Watchdog
SS14 Servers → Port 5000 (HTTP) → Watchdog (internal communication)
Game Server API → Port 1212 (TCP/UDP) → Watchdog
```

**Important**: 
- Port 5000 is for internal container communication only
- Port 5001 is exposed to the host and proxied through Traefik for external access
- Port 1212 is used for server-to-watchdog API communication, not for game clients
- Game clients connect to the SS14 server through different mechanisms

### Useful Commands

```bash
# View logs (equivalent to journalctl -u ss14-watchdog)
docker-compose logs -f ps-ss14-watchdog

# Restart services (equivalent to systemctl restart ss14-watchdog)
docker-compose restart ps-ss14-watchdog

# Stop services (equivalent to systemctl stop ss14-watchdog)
docker-compose down

# Check service status (equivalent to systemctl status ss14-watchdog)
docker-compose ps

# Rebuild after code changes
docker-compose up -d --build
```

### Troubleshooting

#### Network Connectivity Issues (Network is unreachable)

**Problem**: SS14 server getting "Network is unreachable" errors and timing out
```
[ERRO] unobserved: System.AggregateException: ... Network is unreachable
System.Net.Sockets.SocketException (101): Network is unreachable
[WRN] prospect-sector-testing: timed out, killing
```

**Root Cause**: The SS14 server process inside the container cannot reach external services or the watchdog due to network configuration issues.

**Immediate Debugging Steps**:

1. **Test basic connectivity inside container**:
   ```bash
   # Get into the container
   docker-compose exec ps-ss14-watchdog bash
   
   # Test DNS resolution
   nslookup ss14-cdn.prospect-sector.space
   nslookup google.com
   
   # Test external connectivity
   ping -c 3 8.8.8.8
   curl -I https://ss14-cdn.prospect-sector.space/fork/prospect-sector/manifest
   
   # Test internal connectivity
   curl -I http://localhost:5000/health
   ```

2. **Check Docker network configuration**:
   ```bash
   # Check container network settings
   docker inspect PS-SS14-Watchdog | grep -A 20 '"NetworkSettings"'
   
   # Check if container can reach external internet
   docker-compose exec ps-ss14-watchdog curl -I https://google.com
   ```

3. **Check DNS resolution**:
   ```bash
   # Check DNS configuration in container
   docker-compose exec ps-ss14-watchdog cat /etc/resolv.conf
   
   # Test DNS resolution manually
   docker-compose exec ps-ss14-watchdog nslookup ss14-cdn.prospect-sector.space
   ```

**Solutions**:

**Solution 1: DNS Configuration (IMPLEMENTED)**
- Added DNS servers (8.8.8.8, 1.1.1.1) to docker-compose.yml
- Configured DNS in Dockerfile for reliability

**Solution 2: Check Host Network Configuration**
```bash
# On the host system, check if DNS works
nslookup ss14-cdn.prospect-sector.space

# Check if Docker can access external networks
docker run --rm alpine ping -c 3 google.com
```

**Solution 3: Firewall/Network Policy Issues**
- Check if your host firewall is blocking Docker container internet access
- Ensure Docker daemon has internet connectivity
- Check if corporate firewall is blocking the container

**Solution 4: Manual Manifest Download Test**
```bash
# Test if the manifest URL is accessible
curl -v https://ss14-cdn.prospect-sector.space/fork/prospect-sector/manifest

# Check response headers and content
curl -I https://ss14-cdn.prospect-sector.space/fork/prospect-sector/manifest
```

**Solution 5: Alternative BaseUrl Configuration**
If localhost doesn't work, try container IP:
```yaml
# In appsettings.yml, try:
BaseUrl: "http://127.0.0.1:5000/"
# or
BaseUrl: "http://0.0.0.0:5000/"
```

**Network Architecture**:
```
SS14 Server (in container) → localhost:5000 → Watchdog (same container)
SS14 Server (in container) → External Internet → ss14-cdn.prospect-sector.space
External Users → Port 5001 → Traefik → Port 5000 → Watchdog
```

#### Server Ping Issues (400 Bad Request) - DETAILED DEBUGGING

**Problem**: SS14 game server getting 400 Bad Request when trying to ping watchdog
```
[ERRO] watchdogApi: Failed to send ping to watchdog:
System.Net.Http.HttpRequestException: Response status code does not indicate success: 400 (Bad Request).
```

**Root Causes**: This error typically occurs due to:
1. Authorization header parsing issues
2. Secret generation/transmission problems
3. Base URL configuration mismatches
4. Network connectivity issues

**Advanced Debugging Steps**:

1. **Check what the SS14 server is actually sending**:
   ```bash
   # Enable detailed logging to see authorization issues
   docker-compose logs ps-ss14-watchdog | grep -E "(Authorization|401|400|BadRequest|Unauthorized|Secret|ping)"
   ```

2. **Verify the watchdog is accessible internally**:
   ```bash
   # Get into the container
   docker-compose exec ps-ss14-watchdog bash
   
   # Test basic health endpoint
   curl -v http://localhost:5000/health
   
   # This should return: {"status":"healthy","timestamp":"2024-01-01T12:00:00Z"}
   ```

3. **Test the ping endpoint manually**:
   ```bash
   # Get into the container
   docker-compose exec ps-ss14-watchdog bash
   
   # Test the ping endpoint with manual authorization
   # Format: Base64(key:secret)
   KEY="prospect-sector-testing"
   SECRET="<current-secret-from-logs>"
   AUTH=$(echo -n "$KEY:$SECRET" | base64)
   
   curl -X POST -H "Authorization: Basic $AUTH" \
        http://localhost:5000/server_api/prospect-sector-testing/ping -v
   ```

4. **Check server secret generation and environment variables**:
   ```bash
   # Look for secret generation in logs
   docker-compose logs ps-ss14-watchdog | grep -E "(Secret|token|Generated|ROBUST_CVAR)"
   
   # Check if the server process has the right environment variables
   docker-compose exec ps-ss14-watchdog ps aux | grep Robust.Server
   ```

**Common Issues & Solutions**:

**Issue 1: Base URL Configuration Mismatch**
```yaml
# ❌ Wrong - external URL (causes connection failures)
BaseUrl: "https://ss14-watchdog.prospect-sector.space/"

# ❌ Wrong - bind-all address (may cause connection issues)
BaseUrl: "http://0.0.0.0:5000/"

# ✅ Correct - internal localhost URL for container communication
BaseUrl: "http://localhost:5000/"
```

**Issue 2: ASPNETCORE_URLS Configuration**
```bash
# ❌ Wrong - using wildcard that may not resolve properly
ASPNETCORE_URLS=http://+:5000

# ✅ Correct - explicit bind address
ASPNETCORE_URLS=http://0.0.0.0:5000
```

**Issue 3: Authorization Header Parsing**
- The watchdog now properly handles secrets that may contain special characters
- If you see "Failed to parse Basic authentication" in logs, check the authorization header format
- Expected format: `Authorization: Basic <Base64("instance-key:secret")>`

**Issue 4: Secret vs ApiToken Confusion**
- The `ApiToken` in config is for API access (static)
- The `Secret` is for server communication (dynamically generated per restart)
- Server ping uses the **dynamically generated Secret**, not the ApiToken

**Troubleshooting Commands**:
```bash
# Test 1: Check if watchdog responds to health
curl http://localhost:5000/health

# Test 2: Check if the instance exists
curl -X POST http://localhost:5000/server_api/prospect-sector-testing/ping
# Should return 401 Unauthorized (not 404 Not Found)

# Test 3: Check server logs for secret generation
docker-compose logs ps-ss14-watchdog | grep "prospect-sector-testing" | grep -i secret

# Test 4: Test with manual authorization (replace SECRET)
echo -n "prospect-sector-testing:SECRET" | base64
curl -X POST -H "Authorization: Basic <ENCODED_STRING>" \
     http://localhost:5000/server_api/prospect-sector-testing/ping -v
```

**Expected Flow**:
1. **Watchdog starts** and generates a random secret for each server instance
2. **Watchdog launches SS14 server** with environment variable: `ROBUST_CVAR_watchdog__token=<secret>`
3. **SS14 server reads secret** from environment and constructs authorization header
4. **SS14 server sends ping**: `POST /server_api/prospect-sector-testing/ping`
5. **With header**: `Authorization: Basic <Base64("prospect-sector-testing:<secret>")>`
6. **Watchdog validates**: Decodes Base64, splits on first `:`, checks key and secret match

#### Traefik Proxy Configuration Issues

**Problem**: Traefik proxy not configuring itself properly, service not accessible through domain

**Potential Causes**:
- Health check conflicts with Traefik service discovery
- Network configuration issues
- Label configuration problems

**Solutions**:

1. **Check if container is on correct network**:
   ```bash
   docker network ls | grep traefik_lan
   docker network inspect traefik_lan | grep PS-SS14-Watchdog
   ```

2. **Verify Traefik can see the service**:
   ```bash
   # Check Traefik logs for service discovery
   docker logs traefik | grep ps-ss14-watchdog
   ```

3. **Test without health check** (health check temporarily disabled):
   ```bash
   docker-compose down
   docker-compose up -d --build
   ```

4. **Manual health check**:
   ```bash
   # Test if the service responds internally
   docker-compose exec ps-ss14-watchdog curl -f http://127.0.0.1:5000/health
   ```

**Note**: The health check has been temporarily disabled to troubleshoot proxy issues. Re-enable it once Traefik configuration is working.

#### Server Launch Issues

**Problem**: `No such file or directory` error when trying to start `/app/instances/prospect-sector-testing/bin/Robust.Server`

**Root Cause**: The SS14 server binaries haven't been downloaded yet. This can happen when:
- The manifest URL is unreachable
- The download/update process failed
- The server instance is trying to start before the initial update completes

**Debugging Steps**:

1. **Check container logs for update errors**:
   ```bash
   docker-compose logs ps-ss14-watchdog | grep -E "(update|download|manifest|error)"
   ```

2. **Verify the manifest URL is accessible**:
   ```bash
   curl -I https://ss14-cdn.prospect-sector.space/fork/prospect-sector/manifest
   ```

3. **Check instance directory structure**:
   ```bash
   # Check what exists in the instance directory
   docker-compose exec ps-ss14-watchdog ls -la /app/instances/prospect-sector-testing/
   
   # Check if bin directory exists
   docker-compose exec ps-ss14-watchdog ls -la /app/instances/prospect-sector-testing/bin/ 2>/dev/null || echo "bin directory doesn't exist"
   ```

4. **Force an update manually** (if needed):
   ```bash
   # Restart the watchdog to trigger a fresh update attempt
   docker-compose restart ps-ss14-watchdog
   ```

**Expected Directory Structure After Update**:
```
/app/instances/prospect-sector-testing/
├── bin/                    # Server binaries (created by update)
│   ├── Robust.Server      # Main server executable
│   └── ... (other files)
├── config/                # Server configuration
├── data/                  # Server database and data
└── source/                # Git repository (if using Git updates)
```

**Common Solutions**:
- **Check network connectivity**: Ensure the container can reach the manifest URL
- **Verify manifest URL**: Make sure `https://ss14-cdn.prospect-sector.space/fork/prospect-sector/manifest` is correct
- **Wait for initial download**: The first startup may take several minutes to download server files
- **Check disk space**: Ensure sufficient space for server downloads

#### Configuration Validation

**Test Docker Compose configuration**:
```bash
docker-compose config
```

**Check health endpoint**:
```bash
curl http://localhost:5000/health
```

#### Container Won't Start

**Check logs**:
```bash
docker-compose logs ps-ss14-watchdog
```

**Common issues**:
- Network conflicts: Ensure `traefik_lan` network exists
- Port conflicts: Check if port 5000 is available
- Missing files: Ensure `appsettings.yml` exists at the specified path
- Volume mounting: Ensure `/root/ss14-watchdog/instances` directory exists
