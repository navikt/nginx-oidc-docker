# nginx-spa-docker
Docker image to serve single page applications with open id connect auth and proxy settings.


## Configuration


### Environment variables
|Name              |Default value| Comment                                                  |
|------------------|-------------|----------------------------------------------------------|
|APP_CALLBACK_PATH | /callback   | Callback from the OIDC standard                          |
|APP_HOSTNAME      | localhost   |                                                          |
|APP_PATH_PREFIX   | /app-prefix | Context root for the app                                 |
|OIDC_AGENTNAME    |             | Client_id for OIDC                                       |
|OIDC_HOST_URL     |             | `<url>/.well-known/openid-configuration` can be found    |
|OIDC_PASSWORD     |             | Password for OIDC                                        |
|REDIS_HOST        | 0.0.0.0     |       |
|REDIS_PORT        | 6379        |       |
|SESSION_STORAGE   | redis       |       |

### default locations
In the default-config.nginx file you can find the default location configurations that we
have set up. Most important is to add your application to the image. Copy your public files 
to the image `COPY <localroot> /app/<app-prefix>/`. Now fiels

### nginx location configs
The image reads the config files in the `./nginx` folder in the pod. Just files to that
folder. From the test-files:

```nginx
location  /some-prefix-for-proxy-behind-protection {
    access_by_lua_file oidc_protected.lua;
    proxy_pass http://echo-server;
}

location  /some-prefix-for-proxy-without-protection {
    proxy_pass http://echo-server;
}
```

### protected locations
To protect routes add the line `access_by_lua_file oidc_protected.lua;` to the block you want
to protect.

## Testing
I use node, mocha and request to perform test. For testing create a .env file at 
the root of the project containing theese variables.

```
APP_PORT=8012
REDIS_HOST=redis
OIDC_AGENTNAME=foo
OIDC_PASSWORD=bar
OIDC_HOST_URL=http://host.docker.internal:4352
APP_PATH_PREFIX=/test-prefix
```

To test on Docker for mac I use a little "trick" to get OIDC play well with 
`docker-compose`. Simply add `127.0.0.1 host.docker.internal` to the 
hostfile, `/etc/hosts`. The reason for this is that the openidc implementation
this image use https://github.com/zmartzone/lua-resty-openidc uses the service
discovery url from inside the docker-compose network. So you can't simply use 
localhost. Alternatively you could add the internal service name to your hostfile.
The bonus however is that this "trick" can be reused giving you a kind of 
`--network=host` for mac.

```
yarn up
yarn test
```




