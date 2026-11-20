# syntax=docker/dockerfile:1
# Every Dockerfile instruction from the course (Section 3) in one small, runnable image.
# Build:  docker build -t instructions-demo:1.0 .      (run from this folder)

# ARG before FROM: lets you choose the base image version at build time
ARG BASE_TAG=3.20

# FROM: the starting image. Pin a version, never "latest".
FROM alpine:${BASE_TAG}

# LABEL: metadata (who owns it, what it is). Shows in `docker inspect`.
LABEL org.opencontainers.image.title="instructions-demo" \
      org.opencontainers.image.description="One of every Dockerfile instruction" \
      maintainer="you@example.com"

# ARG: a value that exists ONLY while building (not in the running container)
ARG APP_VERSION=1.0.0

# ENV: a value that exists in the running container too (can be overridden with -e)
ENV APP_ENV=dev \
    APP_VERSION=${APP_VERSION}

# WORKDIR: the folder for the instructions below (created if missing)
WORKDIR /app

# RUN: execute a command at build time. One RUN per related step keeps layers few.
RUN apk add --no-cache curl \
 && adduser -D -u 10001 app

# COPY: copy local files in. Prefer COPY over ADD.
COPY --chmod=755 app.sh ./app.sh
COPY --chown=app:app config.txt ./config.txt

# ADD: like COPY, but also extracts a local .tar.gz (and can fetch URLs: avoid that)
ADD bundle.tar.gz ./data/

# EXPOSE: documentation only. It does NOT publish the port (use -p for that).
EXPOSE 8080

# HEALTHCHECK: how Docker decides the container is healthy
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD test -f /app/app.sh || exit 1

# USER: run as a non-root user from here on (security)
USER 10001

# ENTRYPOINT: the fixed program. CMD: its default arguments (easy to override).
ENTRYPOINT ["/app/app.sh"]
CMD ["hello"]
