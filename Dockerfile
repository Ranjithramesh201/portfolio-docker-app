# Base Image
FROM nginx:latest

RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

# Remove the default Nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy portfolio files into Nginx
COPY . /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
CMD wget --spider -q http://localhost || exit 1