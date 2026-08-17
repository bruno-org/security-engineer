FROM node:latest

ARG NPM_TOKEN
ARG DATABASE_PASSWORD
ENV DATABASE_PASSWORD=$DATABASE_PASSWORD

WORKDIR /app
ADD https://example.com/vendor/bundle.tar.gz /app/vendor/
COPY . .
RUN npm install

EXPOSE 3000
CMD ["node", "server.js"]
