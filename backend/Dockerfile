FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY Backend.Api/Backend.Api.csproj Backend.Api/
RUN dotnet restore Backend.Api/Backend.Api.csproj

COPY Backend.Api/ Backend.Api/
RUN dotnet publish Backend.Api/Backend.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Backend.Api.dll"]
