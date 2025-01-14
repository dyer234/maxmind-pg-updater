FROM alpine:latest

RUN apk add --no-cache curl postgresql-client unzip

WORKDIR /usr/local/bin
RUN curl -L -o wait-for-db https://github.com/dyerwolfteam/wait-for-db/releases/download/2023.10.25/wait-for-db --fail
RUN chmod +x wait-for-db

WORKDIR /app
COPY start.sh /app/start.sh

CMD ["sh", "start.sh"]

