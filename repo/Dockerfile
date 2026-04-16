FROM alpine:3.20

RUN apk add --no-cache bash python3 openssh-client

WORKDIR /app
COPY . .
RUN chmod +x scripts/*.sh scripts/*.py

# Use /app/scripts/ as entrypoint so docker compose volume mounts
# (- .:/app) always run the LATEST entrypoint from the repo without
# requiring a docker image rebuild.
ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
CMD ["help"]
