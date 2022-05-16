# NGINX Lua Phantom Token Plugin

[![Quality](https://img.shields.io/badge/quality-experiment-red)](https://curity.io/resources/code-examples/status/)
[![Availability](https://img.shields.io/badge/availability-source-blue)](https://curity.io/resources/code-examples/status/)

A plugin to demonstrate how to implement the [Phantom Token Pattern](https://curity.io/resources/learn/phantom-token-pattern/) via Lua.\
This enables integration with OpenResty or NGINX systems that use the [NGINX Lua module](https://www.nginx.com/resources/wiki/modules/lua/).

## Installation

If you are using luarocks, execute the following command to install the plugin:

```bash
luarocks install lua-resty-phantom-token
```

Or copy the `phantom-token-plugin.lua` file into a directory called `resty` within your `lua_package_path`.

## NGINX Configuration

Introspection results are cached using [ngx.share.DICT](https://github.com/openresty/lua-nginx-module#ngxshareddict) so first use the following NGINX directive:

```nginx
http {
    lua_shared_dict phantom-token 10m;
    server {
        ...
    }
}
```

Then apply the plugin to one or more locations with configuration similar to the following:

```nginx
location ~ ^/ {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'https://login.example.com/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'Password1',
            cache_name = 'phantom-token',
            time_to_live_seconds = 900
        }

        local phantomTokenPlugin = require 'resty.phantom-token'
        phantomTokenPlugin.execute(config)
    }

    proxy_pass https://myapiserver:3000;
}
```

### Configuration Parameters

| Parameter | Required? | Details |
| --------- | --------- | ------- |
| introspection_endpoint | Yes | The path to the Curity Identity Server's introspection endpoint |
| client_id | Yes | The ID of the introspection client configured in the Curity Identity Server |
| client_secret | Yes | The secret of the introspection client configured in the Curity Identity Server |
| cache_name | Yes | The name of the Lua shared dictionary in which introspection results are cached |
| time_to_live_seconds | Yes | The maximum time for which each result is cached |
| scope | No | One or more scopes can be required for the location, such as `read write` |
| trusted_web_origins | No | For browser clients, trusted origins can be configured, so that plugin error responses are readable by Javascript code running in browsers |
| verify_ssl | No | An override that can be set to `false` if using untrusted server certificates in the Curity Identity Server. Alternatively you can specify trusted CA certificates via the `lua_ssl_trusted_certificate` directive. See [lua_resty_http](https://github.com/ledgetech/lua-resty-http#request_uri) for further details. |

## Documentation

See the [OpenResty Integration](https://curity.io/resources/learn/integration-openresty/) article on the Curity Web Site.

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
