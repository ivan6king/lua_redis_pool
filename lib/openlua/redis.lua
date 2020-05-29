-- Order by wangwenguan6 (wangwenguan@jd.com)
-- 2020-05-28 16:49:04
--
local redis = require "resty.redis"


local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 100)
_M._VERSION = '0.01'

local mt = {__index = _M}

function _M.new(self, opts)
    opts = opts or {}
    local red = redis:new()
    red:set_timeout(opts.timeout) -- 1 sec

    local ok, err = red:connect(opts.host, opts.port)
    if not ok then
        ngx.log(ngx.ERR,"failed to connect: " .. err)
        return nil,err
    end

    if opts.password ~= nil then
        local ok, err = red:auth(opts.password)
        if not ok then
            ngx.log(ngx.ERR,"failed to auth: " .. err)
            return nil, err
        end
    end

    return red
end

return _M
