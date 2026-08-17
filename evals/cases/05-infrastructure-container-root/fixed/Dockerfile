# Pinned by digest: the tag can be moved, the digest cannot.
FROM node:22.11.0-alpine@sha256:9f3ec7cd0c9c0e1b8d2f7f6b5c4d3e2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e

WORKDIR /app

# The token is mounted for one command and never lands in a layer.
COPY package.json package-lock.json ./
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN="$(cat /run/secrets/npm_token)" npm ci --ignore-scripts

COPY . .

# Runtime credentials arrive from the environment at run time, not at build time.
USER node

EXPOSE 3000
CMD ["node", "server.js"]
