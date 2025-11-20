FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf.template

# Copy static files
COPY public /usr/share/nginx/html

# Default backend service environment variables
ENV BACKEND_SERVICE_HOST=pickstream-backend \
    BACKEND_SERVICE_PORT=8080

# Create directories with proper permissions for non-root user
RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp /var/run /tmp/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /tmp/nginx /etc/nginx && \
    chmod -R 755 /var/cache/nginx /var/run /tmp/nginx

# Create a script to substitute environment variables
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'envsubst "\$BACKEND_SERVICE_HOST \$BACKEND_SERVICE_PORT" < /etc/nginx/nginx.conf.template > /tmp/nginx/nginx.conf' >> /docker-entrypoint.sh && \
    echo 'exec nginx -c /tmp/nginx/nginx.conf -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# Expose port
EXPOSE 80

# Use the entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]
