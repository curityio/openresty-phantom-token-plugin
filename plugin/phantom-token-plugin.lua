--
-- A LUA module to handle swapping opaque access tokens for JWTs
--

local _M = {}
local http = require "resty.http"
local jwt = require 'resty.jwt'
local str = require 'resty.string'

--
-- Return errors due to invalid tokens or introspection technical problems
--
local function error_response(status, code, message, config)

    local jsonData = '{"code":"' .. code .. '", "message":"' .. message .. '"}'
    ngx.status = status
    ngx.header['content-type'] = 'application/json'

    if config.trusted_web_origins then

        local origin = ngx.req.get_headers()['origin']
        if origin and array_has_value(config.trusted_web_origins, origin) then
            ngx.header['Access-Control-Allow-Origin'] = origin
            ngx.header['Access-Control-Allow-Credentials'] = 'true'
        end
    end
    
    ngx.say(jsonData)
    ngx.exit(status)
end

--
-- Return a generic message for all three of these error categories
--
local function unauthorized_error_response(config)
    error_response(ngx.HTTP_UNAUTHORIZED, 'unauthorized', 'Missing, invalid or expired access token', config)
end

--
-- Introspect the access token
--
local function introspect_access_token(access_token, config)

    local httpc = http:new()
    local introspectCredentials = ngx.encode_base64(config.client_id .. ':' .. config.client_secret)
    local result, error = httpc:request_uri(config.introspection_endpoint, {
        method = 'POST',
        body = 'token=' .. access_token,
        headers = { 
            ['authorization'] = 'Basic ' .. introspectCredentials,
            ['content-type'] = 'application/x-www-form-urlencoded',
            ['accept'] = 'application/jwt'
        },
        ssl_verify = config.verify_ssl or true
    })

    if error then
        local connectionMessage = 'A technical problem occurred during access token introspection'
        ngx.log(ngx.WARN, connectionMessage .. error)
        return { status = 500 }
    end

    if not result then
        return { status = 500 }
    end

    if result.status ~= 200 then
        return { status = result.status }
    end

    -- Get the time to cache from the cache-control header's max-age value
    local expiry = 0
    if result.headers then
        local cacheHeader = result.headers['cache-control']
        if cacheHeader then
            local _, _, expiryMatch = string.find(cacheHeader, "max.-age=(%d+)")
            if expiryMatch then
                expiry = tonumber(expiryMatch)
            end
        end
    end

    return { status = result.status, jwt = result.body, expiry = expiry }
end

--
-- Get the token from the cache or introspect it
--
local function verify_access_token(access_token, config)

    -- Return previous introspeciton results for the same token if available
    local dict = ngx.shared[config.cache_name]
    local existing_jwt = dict:get(access_token)
    if existing_jwt then
        return { status = 200, body = existing_jwt }
    end

    -- Otherwise introspect the opaque access token
    local result = introspect_access_token(access_token, config)
    if result.status == 200 then
        
        local time_to_live = config.time_to_live_seconds
        if result.expiry > 0 and result.expiry < config.time_to_live_seconds then
            time_to_live = result.expiry
        end

        -- Cache the result so that introspection is efficient under load
        -- The opaque access token is already a unique string similar to a GUID so use it as a cache key
        -- The cache is atomic and thread safe so is safe to use across concurrent requests
        -- The expiry value is a number of seconds from the current time
        -- https://github.com/openresty/lua-nginx-module#ngxshareddictset
        dict:set(access_token, result.body, time_to_live)
    end

    return result
end

--
-- The public entry point to introspect the token then forward the JWT to the API
--
function _M.execute(config)

    if ngx.req.get_method() == 'OPTIONS' then
        return
    end

    local auth_header = ngx.req.get_headers()['Authorization']
    if auth_header and string.len(auth_header) > 7 and string.lower(string.sub(auth_header, 1, 7)) == 'bearer ' then

        local access_token = string.sub(auth_header, 8)
        local result = verify_access_token(access_token, config)

        if result.status == 500 then
            error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, 'server_error', 'Problem encountered authorizing the HTTP request', config)
        end

        if result.status ~= 200 then
            ngx.log(ngx.WARN, 'Received a ' .. result.status .. ' introspection response due to the access token being invalid or expired')
            unauthorized_error_response(config)
        end

        ngx.req.set_header('Authorization', 'Bearer ' .. result.jwt)
    else

        ngx.log(ngx.WARN, 'No valid access token was found in the HTTP Authorization header')
        unauthorized_error_response(config)
    end
end

return _M