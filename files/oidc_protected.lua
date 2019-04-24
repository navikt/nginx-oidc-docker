local cookie_secure = "secure; "
local cookie_domain = ""
local is_authorized = false;
local cookies_to_set = {};
local proxy_cookie = {}

if ngx.var.host == "localhost" or ngx.var.host == "frontend" then
    ngx.var.app_baseurl = "http://" .. ngx.var.host .. ":" .. ngx.var.server_port
    local openidc = require("resty.openidc")
    openidc.set_logging(nil, { DEBUG = ngx.INFO })
    ngx.var.session_cookie_secure = "off"
    cookie_secure = ""
else
    cookie_domain = "domain=." .. string.match(ngx.var.host, "%.(.*)") .. "; "
end

local opts = {
    redirect_uri = ngx.var.app_baseurl .. ngx.var.app_callback_path,
    client_id = ngx.var.oidc_agentname,
    client_secret = ngx.var.oidc_password,
    scope = "openid",
    ssl_verify = "no",
    token_endpoint_auth_method = "client_secret_basic",
    discovery = ngx.var.oidc_host_url .. "/.well-known/openid-configuration",
    access_token_expires_leeway = 240,
    iat_slack = 480,
    renew_access_token_on_expiry = true,
    auth_accept_token_as = "cookie:ID_token",
    session_contents = {
        id_token = true,
        enc_id_token = true,
        user = true,
        access_token = true
    }
}

-- If request comes with an Authorization-header we just pass that through.
if ngx.req.get_headers()["Authorization"] then
    is_authorized = true
end

local function set_cookie_if_changed(cookie_name, cookie_value)
    if cookie_value and cookie_value ~= ngx.var["cookie_" .. cookie_name] then
        local cookie_string = cookie_name .. '=' .. cookie_value .. '; ' .. cookie_secure .. cookie_domain .. 'path=/; SameSite=Lax; HttpOnly'
        table.insert(cookies_to_set, cookie_string);
        return true
    end
end

-- Allow for session less authentication. For instance for running cypress tests.
-- Use new cookie name "sut_ID_token", that will override openidc totally.
if ngx.var.cookie_sut_ID_token then
    proxy_cookie.ID_token = ngx.var.cookie_sut_ID_token
    is_authorized = true
    set_cookie_if_changed("ID_token", ngx.var.cookie_sut_ID_token)
end

-- if not autorized then we start that flow.
-- no session is needed if we don't need to get an ID_token.
if not is_authorized then
    -- starting session manual to set some default cookies, etc
    local session, err = require("resty.session").start()

    if not session and err_session then
        ngx.status = 500
        ngx.header.content_type = 'text/plain';
        ngx.say("Problem with getting the session: ", err_session)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    -- since the authenticate might redirect the user we store the ADRUM cookie before a redirect
    if ngx.var.cookie_ADRUM and ngx.var.cookie_ADRUM ~= session.data.ADRUM then
        session.data.ADRUM = ngx.var.cookie_ADRUM
    end

    local unauth_action
    -- dont reautenticate on XHR
    if ngx.var.http_x_requested_with == "XMLHttpRequest" then
        unauth_action = 'pass'
    end

    local res, err = require("resty.openidc").authenticate(opts, nil, unauth_action, session)

    if err then
        ngx.status = 500
        ngx.header.content_type = 'text/plain';
        ngx.say(err)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if ngx.var.uri == ngx.var.app_callback_path then
        return ngx.redirect(ngx.var.app_path_prefix)
    end

    -- syncing cookie from auth result
    if session.data.enc_id_token and set_cookie_if_changed("ID_token", session.data.enc_id_token) then
        -- manually setting access_token_expiration so that it will refresh correctly
        session.data.access_token_expiration = session.data.id_token.exp;
        set_cookie_if_changed("refresh_token", session.data.refresh_token)
    end

    -- adding ADRUM cookie from session if existing
    if session.data.ADRUM then
        proxy_cookie.ADRUM = session.data.ADRUM
    end

    -- adding ID_token if logged in
    if session.data.enc_id_token then
        proxy_cookie.ID_token = session.data.enc_id_token
    end
end

if not proxy_cookie.ADRUM and ngx.var.cookie_ADRUM then
    proxy_cookie.ADRUM = ngx.var.cookie_ADRUM
end

local proxy_cookie_string = ""
for k, v in pairs(proxy_cookie) do
    proxy_cookie_string = proxy_cookie_string .. k .. "=" .. v .. ";"
end
ngx.var.proxy_cookie = proxy_cookie_string

if table.getn(cookies_to_set) > 0 then
    ngx.header['Set-Cookie'] = cookies_to_set
end
