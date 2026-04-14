FROM alpine:3.20

RUN apk add --no-cache bash openssh-client rsync

WORKDIR /app
COPY . .
RUN chmod +x scripts/*.sh

ENV HOST_USER=""
ENV HOST_PROJECT_PATH=""
ENV SIMULATOR="iPhone 17 Pro"

ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["help"]
