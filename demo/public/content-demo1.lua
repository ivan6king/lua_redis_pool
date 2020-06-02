local redis = require("lib/openlua/redis")

local conf = {}
conf.redis = {
    host = '127.0.0.1',
    port = 6379,
    password = nil,    -- 如果不需要密码配置为nil即可
    timeout = 1000,                 -- 连接超时时间(ms)
    max_idle_timeout = 1000,        -- 连接最大空闲时间(ms) 不使用连接池,此配置无效
    pool_size = 100,                -- 单nginx worker进程最大的连接池大小 不使用连接池,此配置无效
}

-- demo1:使用常规操作(不使用连接池 完全兼容lua-resty-redis)
local red = redis:new(conf.redis)

--常规操作
red:set("name","lua_redis_pool(redis demo1)")
ngx.say(red:get("name"))

--管道操作
red:init_pipeline()
red:set("cat", "Marrytmd")
red:set("horse", "Bob")
red:get("cat")
red:get("horse")
local results, err = red:commit_pipeline()
if not results then
    ngx.say("failed to commit the pipelined requests: ", err)
    return
end

for i, res in ipairs(results) do
    ngx.say(tostring(res))
end

