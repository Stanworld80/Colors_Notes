# Dockerfile - Multi-stage build for Colors & Notes (Staging / Testing environment)
# Stage 1: Build the Flutter Web application
FROM ghcr.io/subosito/flutter:3.22.0 AS builder

# Set directory
WORKDIR /app

# Copy dependency configs
COPY pubspec.yaml pubspec.lock ./

# Fetch pub packages
RUN flutter pub get

# Copy all files
COPY . .

# Run Static Analysis & Unit/Widget Tests inside container
RUN flutter analyze
RUN flutter test test/unit
RUN flutter test test/widget

# Build the Flutter web application in release mode for staging
RUN flutter build web --release --dart-define=APP_ENV=staging

# Stage 2: Serve the compiled app with Nginx
FROM nginx:alpine

# Copy built files to Nginx public folder
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose HTTP port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
