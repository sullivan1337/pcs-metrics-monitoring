FROM caddy:latest
RUN apk update && apk add curl jq bash
COPY secrets.env /etc/caddy/secrets.env
COPY Caddyfile /etc/caddy/Caddyfile
COPY prisma_api_script.sh /usr/bin/prisma_api_script.sh
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
RUN chmod +x /usr/bin/prisma_api_script.sh

EXPOSE 80
EXPOSE 443
ENTRYPOINT ["/entrypoint.sh"]
