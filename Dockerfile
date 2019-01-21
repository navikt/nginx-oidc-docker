FROM openresty/openresty:alpine-fat
LABEL maintainer="teamforeldrepenger"

RUN apk add --no-cache bash gettext libintl
USER root
RUN ["luarocks", "install", "lua-resty-session"]
RUN ["luarocks", "install", "lua-resty-http"]
RUN ["luarocks", "install", "lua-resty-jwt"]
RUN ["luarocks", "install", "lua-resty-openidc"]

COPY docker/openidc.lua          /usr/local/openresty/lualib/resty/
COPY docker/default-config.nginx /etc/nginx/conf.d/app.conf.template
COPY docker/oidc_access.lua      /usr/local/openresty/nginx/
COPY docker/start-nginx.sh       /usr/sbin/start-nginx
RUN chmod u+x /usr/sbin/start-nginx
RUN mkdir -p /nginx

ENV APP_DIR="/app"

EXPOSE 9000 8012 443

WORKDIR ${APP_DIR}

CMD ["start-nginx"]
