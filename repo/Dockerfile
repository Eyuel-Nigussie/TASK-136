FROM alpine:3.20

RUN apk add --no-cache bash python3

WORKDIR /app
COPY . .
RUN chmod +x scripts/*.sh scripts/*.py

ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
