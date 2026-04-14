FROM alpine:3.20

RUN apk add --no-cache bash python3 openssh-client

# Copy scripts to /opt so they survive volume mounts on /app
COPY scripts/ /opt/scripts/
RUN chmod +x /opt/scripts/*.sh /opt/scripts/*.py

WORKDIR /app
COPY . .

ENTRYPOINT ["/opt/scripts/docker-entrypoint.sh"]
CMD ["help"]
