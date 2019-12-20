FROM openresty/openresty:alpine-fat
LABEL maintainer="teamtag"

# User env var is needed for luarocks to not complain.
ENV APP_DIR="/app" \
    USER="root"

# Installing the dependencies
RUN apk add --no-cache --update bash gettext libintl openssl \
    && luarocks install lua-resty-session \
    && luarocks install lua-resty-http \
    && luarocks install lua-resty-jwt \
    && luarocks install lua-resty-openidc

# Copying over the config-files.
COPY files/default-config.nginx /etc/nginx/conf.d/app.conf.template
COPY files/oidc_protected.lua   /usr/local/openresty/nginx/
COPY files/start-nginx.sh       /usr/sbin/start-nginx
RUN chmod u+x /usr/sbin/start-nginx
RUN mkdir -p /nginx

EXPOSE 9000 8012 443

WORKDIR ${APP_DIR}

CMD ["start-nginx"]
