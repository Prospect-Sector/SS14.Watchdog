# Use the official .NET 9.0 SDK image to build the application
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Clear any existing NuGet configuration and set up clean config
ENV NUGET_PACKAGES=/root/.nuget/packages
RUN rm -rf /root/.nuget/NuGet/NuGet.Config

# Copy solution file, project files, and NuGet config for restore
COPY *.sln ./
COPY NuGet.config ./
COPY SS14.Watchdog/*.csproj ./SS14.Watchdog/
COPY SS14.Watchdog.Tests/*.csproj ./SS14.Watchdog.Tests/

# Restore dependencies with clean NuGet config
RUN dotnet restore --configfile NuGet.config

# Copy the rest of the source code
COPY . ./

# Build and publish the application for Linux
# Remove --runtime linux-x64 to let .NET choose the best runtime automatically
RUN dotnet publish SS14.Watchdog/SS14.Watchdog.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    --self-contained false

# Build runtime image using ASP.NET runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Add labels for identification
LABEL org.opencontainers.image.title="PS-SS14-Watchdog"
LABEL org.opencontainers.image.description="PS Space Station 14 Watchdog Service"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.os="linux"
LABEL org.opencontainers.image.architecture="amd64"

# Install necessary packages for SS14 server operations and networking tools
# Use standard package installation without version pinning for compatibility
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    unzip \
    git \
    python3 \
    python3-minimal \
    dnsutils \
    net-tools \
    iputils-ping \
    ca-certificates \
    postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Download and install DigitalOcean's CA certificate for secure PostgreSQL connections
RUN wget -O /usr/local/share/ca-certificates/digitalocean-ca.crt \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc || \
    wget -O /usr/local/share/ca-certificates/digitalocean-ca.crt \
    https://certs.secureserver.net/repository/sf-class2-root.crt || \
    echo "Warning: Could not download specific CA certificate, using system defaults"

# Update CA certificate store
RUN update-ca-certificates

# Copy the published application
COPY --from=build /app/publish .

# Create directories for volumes (matching systemctl service expectations)
# Set proper permissions for Linux
RUN mkdir -p /app/data /app/instances /app/logs /app/config \
    && chmod 755 /app/data /app/instances /app/logs /app/config

# Create a non-root user for better security (optional, but recommended)
# Uncomment if you don't need root permissions
# RUN groupadd -r watchdog && useradd -r -g watchdog watchdog
# RUN chown -R watchdog:watchdog /app
# USER watchdog

# Set environment variables for Linux optimization and .NET 9 compatibility
ENV DOTNET_RUNNING_IN_CONTAINER=true
ENV DOTNET_USE_POLLING_FILE_WATCHER=true
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://0.0.0.0:5000
ENV DOTNET_EnableDiagnostics=0

# Expose the ports the app runs on
# Port 5000: Internal server-to-watchdog communication (HTTP)
# Port 5001: External proxy communication (HTTPS via Traefik)
# Port 1212: SS14 game server API communication (TCP/UDP)
# Port 5432: PostgreSQL database for inter-container communication
EXPOSE 5000/tcp
EXPOSE 5001/tcp
EXPOSE 1212/tcp
EXPOSE 1212/udp

# Add health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run as root for now (change to watchdog user if security permits)
ENTRYPOINT ["dotnet", "SS14.Watchdog.dll"]
