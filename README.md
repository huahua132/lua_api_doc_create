这是用于生成 skynet_fly API文档的简易工具。
根据代码中的注释生成markdown 文档

# 例子
```lua
--@API
--@content ---
--@content title: time_util 时间相关
--@content categories: ["skynet_fly API 文档","工具函数"]
--@content category_bar: true
--@content tags: [skynet_fly_api]
--@content ---
--@content [time_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/time_util.lua)
local string_util = require "skynet-fly.utils.string_util"
local skynet
local tonumber = tonumber
local tostring = tostring
local math = math
local assert = assert
local os = os

local M = {
	--1分钟 
	MINUTE = 60,
	--1小时
	HOUR = 60 * 60,
	--1天
	DAY = 60 * 60 * 24,
}

local starttime
--@desc 获取当前时间戳
--@return number 时间戳(秒*100)
function M.skynet_int_time()
	skynet = skynet or require "skynet"
	if not starttime then
		starttime = math.floor(skynet.starttime() * 100)
	end
	return skynet.now() + starttime
end
```

```markdown
---
title: time_util 时间相关
categories: ["skynet_fly API 文档","工具函数"]
category_bar: true
tags: [skynet_fly_api]
---
[time_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/time_util.lua)
## function M.skynet_int_time()
描述: 获取当前时间戳
参数
返回值
* number 时间戳(秒*100)
```