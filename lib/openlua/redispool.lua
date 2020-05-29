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

local common_cmds = {
    "get",      "set",          "mget",     "mset",
    "del",      "incr",         "decr",                 -- Strings
    "llen",     "lindex",       "lpop",     "lpush",
    "lrange",   "linsert",                              -- Lists
    "hexists",  "hget",         "hset",     "hmget",
    "hmset",             "hdel",                 -- Hashes
    "smembers", "sismember",    "sadd",     "srem",
    "sdiff",    "sinter",       "sunion",               -- Sets
    "zrange",   "zrangebyscore", "zrank",   "zadd",
    "zrem",     "zincrby",                              -- Sorted Sets
    "auth",     "eval",         "expire",   "script",
    "sort",                                             -- Others
    "get_reused_times",                                 -- 获取当前链接重用次数
    "close"                                             -- 关闭链接
}

local mt = {__index = _M}


function _M._connect(self)
    local host = rawget(self, "host") or "127.0.0.1"
    local port = rawget(self, "port") or 6379
    local timeout = rawget(self, "timeout") or 3000
    local password = rawget(self, "password")

    local red = redis:new()
    red:set_timeout(timeout)

    local ok, err = red:connect(host, port)
    if not ok then
        ngx.log(ngx.ERR,"redis failed to connect host: " .. err)
        return nil,err
    end

    if password ~= nil then
        local ok, err = red:auth(password)
        if not ok then
            ngx.log(ngx.ERR,"redis failed to auth: " .. err)
            return nil, err
        end
    end
    return red,nil
end


local function _do_command(self,cmd, ...)
    -- 管道命令搜集 走单独流程
    local reqs = rawget(self, "_reqs")
    if reqs then
        reqs[#reqs + 1] = {cmd,...}
        return
    end

    local pool_size = rawget(self,"pool_size")
    local max_idle_timeout = rawget(self,"max_idle_timeout") or 1000

    local red,err = self:_connect()
    if red == nil or err ~= nil then
        return red,err
    end
    local res,err = red[cmd](red,...)
    if not res or err ~= nil then
        return res,err
    end
    if pool_size ~= nil then
        local keepalive_res,keepalive_err = red:set_keepalive(max_idle_timeout, pool_size)
        if not keepalive_res then
            ngx.log(ngx.ERR,"redis failed to set keepalive:" .. keepalive_err)
        end
    end
    return res
end


for i = 1, #common_cmds do
    local cmd = common_cmds[i]

    _M[cmd] =
        function (self, ...)
            return _do_command(self, cmd, ...)
        end
end

function _M.init_pipeline(self,n)
    self._reqs = new_tab(n or 4, 0)
end

function _M.cancel_pipeline(self)
    self._reqs = nil
end

function _M.commit_pipeline(self)
    local reqs = rawget(self,"_reqs")

    local count = #reqs
    if nil == reqs or 0 == count then
        return {}, "no pipeline(redisPool)"
    end

    self._reqs = nil

    local red,err = self:_connect()
    if red == nil or err ~= nil then
        return red,err
    end

    red:init_pipeline(count)
    for _, vals in ipairs(reqs) do
        local cmd = vals[1]
        table.remove(vals , 1)
        red[cmd](red,unpack(vals))
    end
    local results, err = red:commit_pipeline()
    if not results or err then
        return {}, err
    end
    if pool_size ~= nil then
        local keepalive_res,keepalive_err = red:set_keepalive(max_idle_timeout, pool_size)
        if not keepalive_res then
            ngx.log(ngx.ERR,"redis pipeline failed to set keepalive:" .. keepalive_err)
        end
    end

    return results
end

function _M.new(self, opts)
    opts = opts or {}
    opts._reqs = nil
    return setmetatable(opts, mt)
end

return _M
