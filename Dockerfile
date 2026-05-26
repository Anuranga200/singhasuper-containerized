# Multi-stage build for frontend
# Stage 1: Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY bun.lockb* ./

# Install dependencies using npm (or bun if available)
RUN npm ci

# Copy source code
COPY vite.config.ts ./
COPY tsconfig.json ./
COPY tsconfig.app.json ./
COPY tsconfig.node.json ./
COPY postcss.config.js ./
COPY tailwind.config.ts ./
COPY eslint.config.js ./
COPY index.html ./
COPY src ./src
COPY public ./public

# Build the application
RUN npm run build

# Stage 2: Production stage with nginx
FROM nginx:alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Create non-root user
RUN addgroup -g 101 -S nginx && \
    adduser -S nginx -u 101 || true

# Copy nginx configuration
COPY --from=builder /app/dist /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

# # Create custom nginx config
# RUN echo 'server {
#     listen 80;
#     server_name _;
#     root /usr/share/nginx/html;
#     index index.html;

#     # Security headers
#     add_header X-Frame-Options "SAMEORIGIN" always;
#     add_header X-Content-Type-Options "nosniff" always;
#     add_header X-XSS-Protection "1; mode=block" always;
#     add_header Referrer-Policy "no-referrer-when-downgrade" always;

#     # Cache control for static assets
#     location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
#         expires 1y;
#         add_header Cache-Control "public, immutable";
#     }

#     # Route all requests to index.html for SPA
#     location / {
#         try_files $uri $uri/ /index.html;
#     }

#     # Health check endpoint
#     location /health {
#         access_log off;
#         return 200 "healthy\n";
#         add_header Content-Type text/plain;
#     }
# }' > /etc/nginx/conf.d/default.conf

# # Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# Run nginx
CMD ["nginx", "-g", "daemon off;"]
