local redis = require("lib/openlua/redispool")

local conf = {}
conf.redis = {
    host = '127.0.0.1',
    port = 6379,
    password = nil,                 -- 如果不需要密码配置为nil即可
    timeout = 1000,                 -- 连接超时时间(ms)
    max_idle_timeout = 3000,        -- 连接最大空闲时间(ms) 如果pool_size=nil 此配置无效
    pool_size = 100,                 -- 单nginx worker进程最大的连接池大小 如果不需要使用连接池,配置为nil即可
}

-- demo3:使用常规操作(不使用连接池 不兼容lua-resty-redis的订阅、发布命令)
-- redis的专长不是处理订阅、发布场景。如有订阅、发布发布场景请使用专业的mq(rabbitmq/kafka等等)
-- 如果必须使用订阅命令,请参考demo1
-- 使用连接池必须设置lua_code_cache=on
local red = redis:new(conf.redis)


ngx.say("连接复用的次数(每次刷新可见):"..red:get_reused_times())

--常规操作
red:set("name","lua_redis_pool(demo3)")
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

