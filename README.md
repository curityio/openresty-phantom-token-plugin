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
            introspection_endpoint = 'https://login.example.com/oauth/v2/oauth-introspect',
            client_id = 'introspect-client',
            client_secret = 'Password1',
            cache_name = 'phantom-token',
            time_to_live_seconds = 900
        }

        local phantomTokenPlugin = require 'phantom-token-plugin'
        phantomTokenPlugin.execute(config)
    }

    proxy_pass https://myapiserver:3000;
}
```
### Configuration Parameters

`introspection_endpoint`: The path to the Curity Identity Server's introspection endpoint; **REQUIRED**

`client_id`: The ID of the introspection client configured in the Curity Identity Server; **REQUIRED**

`client_secret`: The secret of the introspection client configured in the Curity Identity Server; **REQUIRED**

`cache_name`: The name of the LUA shared dictionary in which introspection results are cached; **REQUIRED**

`time_to_live_seconds`: The maximum time for which each result is cached; **REQUIRED**

`verify_ssl`: Whether or not the server certificate presented by the Identity Server should be validated or not. If set to true, you also have to specify the trusted CA certificates in the `lua_ssl_trusted_certificate` directive. See [https://github.com/ledgetech/lua-resty-http#request_uri](lua_resty_http) for the details. Default `true`; **OPTIONAL** 

`trusted_web_origins`: For browser clients, trusted origins can be configured, so that phantom token plugin error responses include CORS headers to enable Javascript to read the response; **OPTIONAL**

## Documentation

See the [NGINX LUA Integration](https://curity.io/resources/learn/lua-nginx-integration/) article on the Curity Web Site.

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
