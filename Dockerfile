# Build stage - Use .NET 9.0 SDK
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files for dependency restore
COPY *.sln ./
COPY SS14.Watchdog/*.csproj ./SS14.Watchdog/
COPY SS14.Watchdog.Tests/*.csproj ./SS14.Watchdog.Tests/

# Restore NuGet packages
RUN dotnet restore

# Copy source code
COPY . ./

# Build and publish the application
RUN dotnet publish SS14.Watchdog/SS14.Watchdog.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    --self-contained false

# Runtime stage - Use .NET 9.0 ASP.NET runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory and create required directories
WORKDIR /app
RUN mkdir -p data instances logs config

# Copy published application
COPY --from=build /app/publish ./

# Expose ports
EXPOSE 8080/tcp
EXPOSE 1212/tcp
EXPOSE 1212/udp

# Start the application
ENTRYPOINT ["dotnet", "SS14.Watchdog.dll"]
