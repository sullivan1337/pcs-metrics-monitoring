#!/bin/sh

printf '\n%s\n' '*/5 * * * * /bin/bash /usr/bin/prisma_api_script.sh >> /var/log/cron.log 2>&1' > /etc/crontabs/root

/usr/sbin/crond start

/usr/bin/caddy run --config /etc/caddy/Caddyfile

bash /usr/bin/prisma_api_script.sh
