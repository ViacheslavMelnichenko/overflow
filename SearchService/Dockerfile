# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["SearchService/SearchService.csproj", "SearchService/"]
COPY ["Overflow.Common/Overflow.Common.csproj", "Overflow.Common/"]
COPY ["Overflow.ServiceDefaults/Overflow.ServiceDefaults.csproj", "Overflow.ServiceDefaults/"]
COPY ["Overflow.Contracts/Overflow.Contracts.csproj", "Overflow.Contracts/"]
COPY ["Directory.Build.props", "./"]
COPY ["Directory.Packages.props", "./"]

# Restore dependencies
RUN dotnet restore "SearchService/SearchService.csproj"

# Copy everything else
COPY . .

# Build
WORKDIR "/src/SearchService"
RUN dotnet build "SearchService.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "SearchService.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080
EXPOSE 8443

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "SearchService.dll"]

