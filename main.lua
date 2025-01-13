---@diagnostic disable: need-check-nil, undefined-field
local ARGV = {...}
local target_dir = assert(ARGV[1])                  --目标目录
local out_dir = ARGV[2] or "./out"                  --输出目录

local lfs = require "lfs"

local tinsert = table.insert
local tremove = table.remove
local smatch = string.match
local sfind = string.find
local io = io
local assert = assert
local sformat = string.format
local sgsub = string.gsub

local function path_join(a,b)
    if a:sub(-1) == "/" then
        if b:sub(1, 1) == "/" then
            return a .. b:sub(2)
        end
        return a .. b
    end
    if b:sub(1, 1) == '/' then
        return a .. b
    end
    return string.format("%s/%s", a, b)
end

local function convert_windows_to_linux_relative(window_path)
	local linux_path = window_path:gsub("\\", "/")
    return linux_path
end

target_dir = convert_windows_to_linux_relative(target_dir)
out_dir = convert_windows_to_linux_relative(out_dir)

--递归创建文件夹
local function mkdir(path)
    -- 逐层获取并创建每个文件夹
    local current_path = ""

    for part in path:gmatch("([^/\\]+)") do
        current_path = current_path .. part .. "/"
        -- 检查当前路径是否存在
        if lfs.attributes(current_path:sub(1, current_path:len() - 1)) == nil then
            -- 如果不存在，则创建目录
            local success, err = lfs.mkdir(current_path)
            if not success then
                return nil, "Error creating directory: " .. current_path .. " - " .. err
            end
        end
    end

    return true
end

local function diripairs(path_url, max_depth)
	local stack = {}
	
	local function push_stack(path, depth)
		local next,meta1,meta2 = lfs.dir(path)
        
		tinsert(stack,{
			path = path,
			next = next,
			meta1 = meta1,
			meta2 = meta2,
			depth = depth,
		})
	end

	local root_info = lfs.attributes(path_url)
    
	if root_info and root_info.mode == 'directory' then
		push_stack(path_url, 0)
	end

	return function() 
		while #stack > 0 do
			local cur = stack[#stack]
			local file_name = cur.next(cur.meta1,cur.meta2)
			if file_name == '..' or file_name == '.' then
			elseif file_name then
				local file_path = path_join(cur.path, '/' .. file_name)
				local file_info, errmsg, errno = lfs.attributes(file_path)
				local depth = cur.depth
				if file_info and file_info.mode == 'directory' then
					if not max_depth or depth < max_depth then
						push_stack(file_path, depth + 1)
					end
				end
				return file_name, file_path, file_info, errmsg, errno
			else
				tremove(stack,#stack)
			end
		end
		return nil,nil,nil
	end
end

local STATE_TYPE = {
    head = 1,       --查找API头 标记 @API
    content = 2,    --写内容状态
}

local CONTENT = "---#content"
local DESC = "---#desc"
local PAREAM = "---@param"
local RETURN = "---@return"

--创建mark down
local function check_create_markdown(file_name, file_path)
    local file = io.open(file_path, 'r')
    assert(file, "can`t open file_path:" .. file_path)
    local state = STATE_TYPE.head
    local mk_file = nil

    --查找头
    local function find_head(line)
        if sfind(line, "#API", nil, true) then  --API头标记
            local _,e = sfind(file_path, target_dir, nil, true)
            local out_path = path_join(out_dir, file_path:sub(e + 1))
            local b = sfind(out_path, file_name, nil, true)
            mkdir(out_path:sub(1, b-1))
            local out_path = sgsub(out_path, '.lua', '.md')
            mk_file = io.open(out_path, 'w+')
            assert(mk_file, "can`t open file_path:" .. out_path)
            state = STATE_TYPE.content
        end
    end

    local api_info = {
        desc = nil,
        params = {},
        returns = {},
    }
    --写内容
    local function write_body(line)
        if line:sub(1, 8) == 'function' then
            if not api_info.desc then
                return
            end

            mk_file:write(sformat("## %s\n", line))
            mk_file:write(sformat("**描述**\n\n%s\n", api_info.desc))
            mk_file:write(sformat("**参数**\n"))
            for i = 1, #api_info.params do
                mk_file:write(sformat("* %s\n", api_info.params[i]))
            end
            mk_file:write(sformat("\n**返回值**\n"))
            for i = 1, #api_info.returns do
                mk_file:write(sformat("* %s\n", api_info.returns[i]))
            end
            mk_file:write(sformat("\n"))
            api_info.desc = nil
            api_info.params = {}
            api_info.returns = {}
        else
            if sfind(line, "#desc", nil, true) then
                local desc = line:sub(DESC:len() + 2)
                api_info.desc = desc
            elseif sfind(line, "#content", nil, true) then
                local content = line:sub(CONTENT:len() + 2)
                mk_file:write(content .. '\n')
            else
                local opt = smatch(line, "@(%a+)")
                if not opt then
                    return 
                end
                if opt == "param" then
                    local param = line:sub(PAREAM:len() + 2)
                    tinsert(api_info.params, param)
                elseif opt == "return" then
                    local str = line:sub(RETURN:len() + 2)
                    tinsert(api_info.returns, str)
                end
            end
        end
    end

    for line in file:lines() do
        if state == STATE_TYPE.head then
            find_head(line)
        else
            write_body(line)
        end
    end
    file:close()
    if mk_file then
        mk_file:flush()
        mk_file:close()
    end
end

if target_dir:sub(#target_dir-1,#target_dir) == '/' then
    target_dir = target_dir:sub(1, #target_dir - 1)
end

for file_name, file_path, file_info, errmsg, errno in diripairs(target_dir) do
    if sfind(file_name, 'lua', nil, true) then
        check_create_markdown(file_name, file_path)
    end
end