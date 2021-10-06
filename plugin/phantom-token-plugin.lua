--
-- A LUA module to handle swapping opaque access tokens for JWTs
--

local _M = {}
local http = require "resty.http"
local jwt = require 'resty.jwt'
local pl_stringx = require "pl.stringx"

--
-- Return errors due to invalid tokens or introspection technical problems
--
local function error_response(status, code, message)

    local jsonData = '{"code":"' .. code .. '", "message":"' .. message .. '"}'
    ngx.status = status
    ngx.header['content-type'] = 'application/json'

    if config.trusted_web_origins then

        local origin = ngx.req.get_headers()["origin"]
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
local function invalid_token_error_response(config)
    error_response(ngx.HTTP_UNAUTHORIZED, "unauthorized", "Missing, invalid or expired access token", config)
end

--
-- Introspect the access token
--
local function introspect_access_token(access_token, config)

    local httpc = http:new()
    local introspectCredentials = ngx.encode_base64(config.client_id .. ":" .. config.client_secret)
    local result, error = httpc:request_uri(config.introspection_endpoint, {
        method = "POST",
        body = "token=" .. access_token,
        headers = { 
            ["authorization"] = "Basic " .. introspectCredentials,
            ["content-type"] = "application/x-www-form-urlencoded",
            ["accept"] = "application/jwt"
        }
    })

    if error then
        local connectionMessage = "A technical problem occurred during access token introspection"
        ngx.log(ngx.WARN, connectionMessage .. error)
        return { status = 0 }
    end

    if not result then
        return { status = 0 }
    end

    if result.status ~= 200 then
        return { status = result.status }
    end

    return { status = result.status, body = result.body }
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
        
        -- Cache the result so that introspection is efficient under load
        -- The opaque access token is already a unique string similar to a GUID so use it as a cache key
        -- The cache is atomic and thread safe so is safe to use across concurrent requests
        -- The expiry value is a number of seconds from the current time
        -- https://github.com/openresty/lua-nginx-module#ngxshareddictset
        dict:set(access_token, result.body, config.time_to_live_seconds)
    end

    return result
end

--
-- The public entry point to introspect the token then forward the JWT to the API
--
function _M.execute(config)

    if ngx.req.get_method() == "OPTIONS" then
        return
    end

    local access_token = ngx.req.get_headers()["Authorization"]
    if access_token then
        access_token = pl_stringx.replace(access_token, "Bearer ", "", 1)
    end

    if not access_token then
        ngx.log(ngx.WARN, "No access token was found in the HTTP Authorization header")
        invalid_token_error_response(config)
    end

    local result = verify_access_token(access_token, config)
    if result.status == 204 then
        ngx.log(ngx.WARN, "Received a " .. result.status .. " introspection response due to the access token being invalid or expired")
        invalid_token_error_response(config)
    end

    local jwt = result.body
    ngx.req.set_header("Authorization", "Bearer " .. jwt)
end

return _M