# LUA NGINX Phantom Token Plugin

[![Quality](https://img.shields.io/badge/quality-experiment-red)](https://curity.io/resources/code-examples/status/)
[![Availability](https://img.shields.io/badge/availability-source-blue)](https://curity.io/resources/code-examples/status/)

A plugin to demonstrate how to implement the [Phantom Token Pattern](https://curity.io/resources/learn/phantom-token-pattern/) via LUA.\
This enables integration with OpenResty or NGINX systems that use the [NGINX LUA module](https://www.nginx.com/resources/wiki/modules/lua/).

## NGINX Setup

Introspection results are cached using [ngx.share.DICT](https://github.com/openresty/lua-nginx-module#ngxshareddict) so first use the following NGINX directive:

```nginx
http {
    lua_shared_dict phantom-token 10m;
    server {
    }
}
```

Then apply the plugin to one or more locations with configuration similar to the following:

```nginx
location ~ ^/ {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'https://login.example.com:8443/oauth/v2/oauth-introspect',
            client_id = 'introspect-client',
            client_secret = 'Password1',
            cache_name = 'phantom-token',
            time_to_live_seconds = 900
        }

        local phantomTokenPlugin = require 'phantom-token-plugin'
        phantomTokenPlugin.execute(config)
    }
}

## Documentation

This repository is documented in the [LUA API Gateway Integration](https://curity.io/resources/learn/lua-nginx-integration/) article on the Curity Web Site.

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
