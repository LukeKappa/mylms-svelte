# Multi-stage build for SvelteKit
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

# Copy built assets from builder
COPY --from=builder /app/build build/
COPY --from=builder /app/package.json .
COPY --from=builder /app/node_modules node_modules/

# Set environment variables
ENV NODE_ENV=production
# Hardcode port 2005 as requested
ENV PORT=2005
ENV HOST=0.0.0.0

# Expose port
EXPOSE 2005

# Start the server
CMD ["node", "build"]
