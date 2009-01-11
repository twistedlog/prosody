
local open = io.open;
local t_concat = table.concat;

local http_base = "www_files";

local response_404 = { status = "404 Not Found", body = "<h1>Page Not Found</h1>Sorry, we couldn't find what you were looking for :(" };

local http_path = { http_base };
local function handle_request(method, body, request)
	local path = request.url.path:gsub("%.%.%/", ""):gsub("^/[^/]+", "");
	http_path[2] = path;
	local f, err = open(t_concat(http_path), "r");
	if not f then return response_404; end
	local data = f:read("*a");
	f:close();
	return data;
end

httpserver.new{ port = 5280, base = "files", handler = handle_request, ssl = false}