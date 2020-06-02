名称
======

lua_redis_pool：redis连接池，无缝兼容`resty.redis`。

介绍
======

通过对`resty.redis`类库的封装简化redis连接池的使用成本。使用习惯与resty.redis类库完全兼容，可以非常简单的实现升级切换。

样例
========
Nginx配置demo
```nginx
#增加包路径
lua_package_path "/export/App/openlua/lua_redis_pool/?.lua;;";

server {
    listen  80 default_server;
    server_name    _;

    charset utf-8;
    default_type   text/plain;

    lua_code_cache on;

    #设置入口路径
    access_log  /var/nginx_log/lua_redis_pool-access.log main;
    error_log   /var/nginx_log/lua_redis_pool-error.log debug;

    set $public_path "/export/App/openlua/lua_redis_pool/demo/public";

    index index.html;

    location = /demo1 {
        content_by_lua_file $public_path/content-demo1.lua;
    }

    location = /demo2 {
        content_by_lua_file $public_path/content-demo2.lua;
    }

    location = /demo3 {
        content_by_lua_file $public_path/content-demo3.lua;
    }
}
```

业务代码demo
```lua
local redis = require("lib/openlua/redispool")

local conf = {}
conf.redis = {
    host = '127.0.0.1',
    port = 6379,
    password = nil,-- 如果不需要密码配置为nil即可
    timeout = 1000,          -- 连接超时时间(ms)
    max_idle_timeout = 3000, -- 连接最大空闲时间(ms) 如果pool_size=nil 此配置无效
    pool_size = 100,         -- 单nginx worker进程最大的连接池大小 如果不需要使用连接池,配置为nil即可
}

-- demo3:使用常规操作(不使用连接池 不兼容lua-resty-redis的订阅、发布命令)
-- redis的专长不是处理订阅、发布场景。如有订阅、发布发布场景请使用专业的mq(rabbitmq/kafka等等)
-- 如果必须使用订阅命令,请参考demo1
-- 使用连接池必须设置lua_code_cache=on
local red = redis:new(conf.redis)

ngx.say("连接复用的次数(每次刷新可见):"..red:get_reused_times())

--常规操作
red:set("name","lua_redis_pool(redis demo3)")
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
```
------

引入
======
直接将代码库部署到业务类库目录即可，然后在`nginx`的`lua_package_path`配置引入路径即可


方法
======
lua_redis_pool除了初始化命令new,redis的所有执行命令均与`resty.redis`保持统一

new
---
`syntax: red = redis:new(options_table)`

初始化redis

入参 `options_table`是lua table，包含redis相关配置信息，包含以下键：

* `host`
    
    配置redis地址(e.g. `127.0.0.1`) 

    默认值：`127.0.0.1`

* `port`
    
    配置redis端口号(e.g. `6379`) 
    
    默认值：`6379`

* `timeout`
    
    连接超时时间(e.g. `1000`) 
    
    默认值：`3000`

    单位：毫秒(ms)

* `password`
    
    配置redis密码，如果不需要验证直接配置`nil`即可(e.g. `nil`)
    
    默认值：`nil` 

* `max_idle_timeout`
    
    配置redis连接最大空闲时间，即无操作的状态下保持连接的最大时间。当连接空闲时间自动断开，下次请求将重新建立连接。此配置参数依赖`pool_size`配置参数，如果`pool_size=nil`，此参数不生效(e.g. `1000`) 
    
    默认值：`3000`    
    
    单位：毫秒(ms)

* `pool_size`
    
    配置redis连接池大小，此连接池大小为nginx worker的连接池大小，整个nginx服务的连接池总数=`worker_processes*pool_size`。如果业务流量不大，不需启用连接池，直接配置为`nil`即可(e.g. `nil` or `10`) 
    
    默认值：`nil`


常规方法
---
`syntax: res, err = red:{cmd}(...)`

lua_redis_pool类库包含以下执行方法，使用方式与resty.redis兼容，具体使用方式参考：https://github.com/openresty/lua-resty-redis

```lua
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
```
返回值：当`res=nil`说明redis连接失败或者密码认证失败,需从`err`结果查看具体的错误信息。如果`res=ngx.null`说明连接正常，但是redis无此数据。


init_pipeline
---
`syntax: red:init_pipeline()`

启用管道模式，此命令使用方法同resty.redis类库使用方法，参考：https://github.com/openresty/lua-resty-redis#init_pipeline


commit_pipeline
---
`syntax: results, err = red:commit_pipeline()`

管道命令同resty.redis类库使用方法，参考：https://github.com/openresty/lua-resty-redis#commit_pipeline


cancel_pipeline
---
`syntax: results = red:cancel_pipeline()`

管道命令同resty.redis类库使用方法，参考：https://github.com/openresty/lua-resty-redis#cancel_pipeline

get_reused_times
---
`syntax: times, err = red:get_reused_times()`

此方法返回当前连接的（成功）重用次数，参考：https://github.com/openresty/lua-resty-redis#get_reused_times

其他
======
如果业务流量不大，不需要使用连接池，可以参考代码库的demo1(完全兼容`resty.redis`)或者demo2。



