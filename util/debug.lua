-- Variables ending with these names will not
-- have their values printed ('password' includes
-- 'new_password', etc.)
local censored_names = {
	password = true;
	passwd = true;
	pass = true;
	pwd = true;
};

local function get_locals_table(level)
	level = level + 1; -- Skip this function itself
	local locals = {};
	for local_num = 1, math.huge do
		local name, value = debug.getlocal(level, local_num);
		if not name then break; end
		table.insert(locals, { name = name, value = value });
	end
	return locals;
end

local function get_upvalues_table(func)
	local upvalues = {};
	if func then
		for upvalue_num = 1, math.huge do
			local name, value = debug.getupvalue(func, upvalue_num);
			if not name then break; end
			table.insert(upvalues, { name = name, value = value });
		end
	end
	return upvalues;
end

local function string_from_var_table(var_table, max_line_len, indent_str)
	local var_string = {};
	local col_pos = 0;
	max_line_len = max_line_len or math.huge;
	indent_str = "\n"..(indent_str or "");
	for _, var in ipairs(var_table) do
		local name, value = var.name, var.value;
		if name:sub(1,1) ~= "(" then
			if type(value) == "string" then
				if censored_names[name:match("%a+$")] then
					value = "<hidden>";
				else
					value = ("%q"):format(value);
				end
			else
				value = tostring(value);
			end
			if #value > max_line_len then
				value = value:sub(1, max_line_len-3).."…";
			end
			local str = ("%s = %s"):format(name, tostring(value));
			col_pos = col_pos + #str;
			if col_pos > max_line_len then
				table.insert(var_string, indent_str);
				col_pos = 0;
			end
			table.insert(var_string, str);
		end
	end
	if #var_string == 0 then
		return nil;
	else
		return "{ "..table.concat(var_string, ", "):gsub(indent_str..", ", indent_str).." }";
	end
end

function get_traceback_table(thread, start_level)
	local levels = {};
	for level = start_level, math.huge do
		local info;
		if thread then
			info = debug.getinfo(thread, level);
		else
			info = debug.getinfo(level);
		end
		if not info then break; end
		
		levels[(level-start_level)+1] = {
			level = level;
			info = info;
			locals = get_locals_table(level);
			upvalues = get_upvalues_table(info.func);
		};
	end	
	return levels;
end

function debug.traceback(thread, message, level)
	if type(thread) ~= "thread" then
		thread, message, level = coroutine.running(), thread, message;
	end
	if level and type(message) ~= "string" then
		return nil, "invalid message";
	elseif not level then
		level = message or 2;
	end
	
	message = message and (message.."\n") or "";
	
	local levels = get_traceback_table(thread, level+2);
	
	local lines = {};
	for nlevel, level in ipairs(levels) do
		local info = level.info;
		local line = "...";
		local func_type = info.namewhat.." ";
		if func_type == " " then func_type = ""; end;
		if info.short_src == "[C]" then
			line = "[ C ] "..func_type.."C function "..(info.name and ("%q"):format(info.name) or "(unknown name)")
		elseif info.what == "main" then
			line = "[Lua] "..info.short_src.." line "..info.currentline;
		else
			local name = info.name or " ";
			if name ~= " " then
				name = ("%q"):format(name);
			end
			if func_type == "global " or func_type == "local " then
				func_type = func_type.."function ";
			end
			line = "[Lua] "..info.short_src.." line "..info.currentline.." in "..func_type..name.." defined on line "..info.linedefined;
		end
		nlevel = nlevel-1;
		table.insert(lines, "\t"..(nlevel==0 and ">" or " ").."("..nlevel..") "..line);
		local npadding = (" "):rep(#tostring(nlevel));
		local locals_str = string_from_var_table(level.locals, 65, "\t            "..npadding);
		if locals_str then
			table.insert(lines, "\t    "..npadding.."Locals: "..locals_str);
		end
		local upvalues_str = string_from_var_table(level.upvalues, 65, "\t            "..npadding);
		if upvalues_str then
			table.insert(lines, "\t    "..npadding.."Upvals: "..upvalues_str);
		end
	end
	return message.."stack traceback:\n"..table.concat(lines, "\n");
end
