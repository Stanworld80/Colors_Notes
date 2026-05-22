# run_docker.ps1 - Powershell helper script for local Docker testing
param (
    [string]$Option = "help"
)

function Print-Help {
    Write-Host "Colors & Notes - Local Docker Testing Helper (PowerShell)" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "Usage: .\run_docker.ps1 -Option [fast|full|tests|stop]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  fast       (Recommended) Compiles Flutter web locally on your machine,"
    Write-Host "             then runs Nginx inside a lightweight Docker container."
    Write-Host "             Access at: http://localhost:8080"
    Write-Host ""
    Write-Host "  full       Runs a fully containerized build inside Docker (compilation"
    Write-Host "             and tests run inside a Flutter container). Takes longer."
    Write-Host "             Access at: http://localhost:8081"
    Write-Host ""
    Write-Host "  tests      Runs the complete unit and widget test suite inside Docker."
    Write-Host ""
    Write-Host "  stop       Stops all running Colors & Notes containers."
}

switch ($Option) {
    "fast" {
        Write-Host "⚡ Starting FAST Local Deployment..." -ForegroundColor Yellow
        Write-Host "1. Building Flutter Web on your machine (Staging mode)..." -ForegroundColor Yellow
        flutter build web --release --dart-define=APP_ENV=staging
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Host compilation failed! Exiting."
            exit 1
        }
        Write-Host "2. Launching lightweight Nginx container..." -ForegroundColor Yellow
        docker compose up --build -d web-fast
        Write-Host "`n✅ Started successfully!" -ForegroundColor Green
        Write-Host "🔗 Open http://localhost:8080 in your browser to test the deployed app." -ForegroundColor Green
    }
    "full" {
        Write-Host "🐳 Starting FULL Container Build (Self-contained)..." -ForegroundColor Yellow
        Write-Host "This compiles and runs tests inside Docker. Please be patient..." -ForegroundColor Yellow
        docker compose up --build -d web-full
        Write-Host "`n✅ Started successfully!" -ForegroundColor Green
        Write-Host "🔗 Open http://localhost:8081 in your browser to test the deployed app." -ForegroundColor Green
    }
    "tests" {
        Write-Host "🧪 Running Test Suite inside Docker Container..." -ForegroundColor Yellow
        docker compose run --rm tests
    }
    "stop" {
        Write-Host "🛑 Stopping all containers..." -ForegroundColor Yellow
        docker compose down
        Write-Host "✅ Stopped." -ForegroundColor Green
    }
    Default {
        Print-Help
    }
}
