FROM node:18-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache curl postgresql-client

# Copy package files
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY src-node/ src/
COPY data/ data/

# Create data directory if it doesn't exist
RUN mkdir -p /app/data

# Expose ports
EXPOSE 3000 9229

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["npm", "run", "dev"]