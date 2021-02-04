FROM almir/webhook:2.8.0
LABEL org.opencontainers.image.source https://github.com/brianbrowndev/personal-server

RUN adduser -D -u 1000 b && \
  apk add --no-cache kubectl --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing

USER b