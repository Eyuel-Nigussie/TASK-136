FROM alpine:3.20

RUN apk add --no-cache bash python3 openssh-client

WORKDIR /app
COPY . .
RUN chmod +x scripts/*.sh

ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["help"]
