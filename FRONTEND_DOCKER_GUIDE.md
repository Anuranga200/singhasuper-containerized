# Frontend Docker Image Guide

This guide explains how to build and run the Docker image for the frontend application.

## Prerequisites

- Docker installed (v20.10+)
- Docker Compose installed (v1.29+)

## Building the Frontend Docker Image

### Build the image manually

```bash
# Build the image
docker build -f Dockerfile.frontend -t my-app-frontend:latest .

# Or with a specific tag
docker build -f Dockerfile.frontend -t my-app-frontend:1.0.0 .
```

### Build with Docker Compose

```bash
# Build only the frontend
docker-compose build frontend

# Build both frontend and backend
docker-compose build
```

## Running the Container

### Run standalone

```bash
# Run the frontend container
docker run -p 80:80 \
  -e VITE_API_BASE_URL=http://backend:3000 \
  my-app-frontend:latest
```

### Run with Docker Compose

```bash
# Start both frontend and backend
docker-compose up -d

# View logs
docker-compose logs -f frontend

# Stop services
docker-compose down
```

## Environment Variables

The following environment variables can be configured:

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_API_BASE_URL` | Backend API base URL | `http://localhost:3000` |

## Port Configuration

- **Frontend (Nginx)**: Port 80 (HTTP)
- **Backend (Node.js)**: Port 3000

## Accessing the Application

Once the container is running:

```
Frontend: http://localhost
Backend: http://localhost:3000
```

## Health Check

The frontend includes a health check endpoint at `/health` that returns a `200 OK` status if the container is healthy.

Test it with:

```bash
curl http://localhost/health
```

## Multi-Stage Build Explanation

The Dockerfile uses a multi-stage build process:

1. **Builder Stage** (node:18-alpine)
   - Installs dependencies
   - Compiles TypeScript with Vite
   - Produces optimized `dist/` folder

2. **Production Stage** (nginx:alpine)
   - Copies only the built files from the builder stage
   - Runs lightweight nginx server
   - Serves static SPA files with proper routing
   - Adds security headers
   - Implements caching strategy for static assets

## Benefits of This Approach

- **Small Image Size**: Only production dependencies included (~50MB)
- **Security**: Non-root user, minimal attack surface, Alpine Linux base
- **Performance**: Nginx serves static files efficiently, proper caching
- **SPA Support**: `try_files` directs all routes to index.html
- **Health Checks**: Built-in container health monitoring
- **Production Ready**: Security headers, cache control, optimized for AWS

## Docker Compose Features

The provided `docker-compose.yml`:

- Runs frontend on port 80
- Runs backend on port 3000
- Sets up network communication between services
- Includes health checks for both services
- Supports environment variables via `.env` file

## Creating .env File (Optional)

Create a `.env` file in the project root for Docker Compose:

```bash
DATABASE_URL=postgresql://user:password@db-host:5432/dbname
JWT_SECRET=your-jwt-secret
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
VITE_API_BASE_URL=http://localhost:3000
```

## Development vs Production

### Development (Local)

```bash
npm run dev
# Runs on http://localhost:8080 with hot reload
```

### Production (Docker)

```bash
docker-compose up
# Optimized build served by nginx on http://localhost
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs frontend

# Verify build
docker build -f Dockerfile.frontend --no-cache .
```

### 404 errors on page refresh

This is typically not an issue if the Dockerfile is correct—it should route all requests to `index.html` for SPA routing. Verify the nginx configuration in the Dockerfile.

### API connection issues

Ensure the `VITE_API_BASE_URL` environment variable matches your backend URL.

## Advanced Usage

### Push to Docker Registry (Docker Hub, AWS ECR, etc.)

```bash
# Tag the image
docker tag my-app-frontend:latest your-registry/my-app-frontend:latest

# Push
docker push your-registry/my-app-frontend:latest
```

### Using with AWS ECR

```bash
# Create ECR repository
aws ecr create-repository --repository-name my-app-frontend

# Get login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -f Dockerfile.frontend -t YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-app-frontend:latest .
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-app-frontend:latest
```

## Next Steps

1. Test the image locally with `docker-compose up`
2. Push to your container registry (Docker Hub, AWS ECR, etc.)
3. Deploy to your infrastructure (ECS, EKS, App Runner, etc.)
4. Update deployment pipelines to use the new frontend image

For deployment to AWS infrastructure, refer to your existing CI/CD configuration in the `infrastructure/` folder.
