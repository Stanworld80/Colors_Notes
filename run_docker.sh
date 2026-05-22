#!/bin/bash

# ==============================================================================
# run_docker.sh - Helper script for local Docker testing of Colors & Notes
# ==============================================================================

print_help() {
    echo "Colors & Notes - Local Docker Testing Helper"
    echo "=========================================="
    echo "Usage: ./run_docker.sh [option]"
    echo ""
    echo "Options:"
    echo "  --fast       (Recommended) Compiles Flutter web locally on your machine,"
    echo "               then runs Nginx inside a lightweight Docker container."
    echo "               Access at: http://localhost:8080"
    echo ""
    echo "  --full       Runs a fully containerized build inside Docker (compilation"
    echo "               and tests run inside a Flutter container). Takes longer."
    echo "               Access at: http://localhost:8081"
    echo ""
    echo "  --tests      Runs the complete unit and widget test suite inside Docker."
    echo ""
    echo "  --stop       Stops all running Colors & Notes containers."
    echo "  -h, --help   Affiche ce message d'aide."
}

case "$1" in
    --fast)
        echo "⚡ Starting FAST Local Deployment..."
        echo "1. Building Flutter Web on your machine (Staging mode)..."
        flutter build web --release --dart-define=APP_ENV=staging
        if [ $? -ne 0 ]; then
            echo "❌ Host compilation failed! Exiting."
            exit 1
        fi
        echo "2. Launching lightweight Nginx container..."
        docker compose up --build -d web-fast
        echo "✅ Started successfully!"
        echo "🔗 Open http://localhost:8080 in your browser to test the deployed app."
        ;;
    --full)
        echo "🐳 Starting FULL Container Build (Self-contained)..."
        echo "This compiles and runs tests inside Docker. Please be patient..."
        docker compose up --build -d web-full
        echo "✅ Started successfully!"
        echo "🔗 Open http://localhost:8081 in your browser to test the deployed app."
        ;;
    --tests)
        echo "🧪 Running Test Suite inside Docker Container..."
        docker compose run --rm tests
        ;;
    --stop)
        echo "🛑 Stopping all containers..."
        docker compose down
        echo "✅ Stopped."
        ;;
    -h|--help|*)
        print_help
        ;;
esac
