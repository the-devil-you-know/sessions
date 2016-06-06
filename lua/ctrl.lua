local json = require('json')
local sBox = require '/lua/sBox'

local function rendSuccess(req, data)
    return req:render { json = { status = 'success', data = data } }
end

local function rendError(req, message, code)
    return req:render { json = { status = 'error', message = message, code = code } }
end

local function tuple2Json(tuple)
    local ip, info = tuple[sBox.col.ip], tuple[sBox.col.info] -- optional cols
    return {
        token = tuple[sBox.col.token],
        user_id = tuple[sBox.col.userId],
        create = tuple[sBox.col.create],
        activity = tuple[sBox.col.activity],
        ip = ip and ip or json.NULL,
        info = info and info or json.NULL
    }
end

local function urlDecode(str)
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return str
end


local function new(req)
    local userId, ip, info = req:param('user_id'), req:param('ip'), req:param('info') -- info is optional
    if (not tonumber(userId)) then return rendError(req, 'invalid userId', 'invalid_user_id') end
    return rendSuccess(req, tuple2Json(sBox.space:insert {
        require('uuid').str(),
        math.floor(userId),
        ip,
        os.time(),
        os.time(),
        info and urlDecode(info) or nil
    }))
end

local function get(req)
    local token, ip, info = req:param('token'), req:param('ip'), req:param('info') -- ip and info is optional
    if (not token) then return rendError(req, 'token not found', 'token_not_found'); end

    local updateData = { { '=', sBox.col.activity, os.time() } }
    if (info and info ~= '') then table.insert(updateData, { '=', sBox.col.info, urlDecode(info) }) end
    if (ip and ip ~= '') then table.insert(updateData, { '=', sBox.col.ip, ip }) end

    local tuple = sBox.space:update(token, updateData)
    if (not tuple) then return rendError(req, 'token not found', 'token_not_found'); end

    return rendSuccess(req, tuple2Json(tuple))
end

local function del(req)
    local token = req:param('token')
    if (not token) then return rendError(req, 'token not found', 'token_not_found'); end
    local tuple = sBox.space:delete(token)
    if (not tuple) then return rendError(req, 'token not found', 'token_not_found'); end
    return rendSuccess(req, tuple2Json(tuple))
end

local function user(req)
    local userId = req:param('id')
    if (not tonumber(userId)) then return rendError(req, 'invalid userId', 'invalid_user_id') end
    local tuples = sBox.space.index[sBox.index.userId]:select({ math.floor(userId) }, { iterator = 'REQ' })
    local res = {}
    for i = 1, #tuples, 1 do table.insert(res, tuple2Json(tuples[i])) end
    return rendSuccess(req, res)
end

return {
    new = new,
    get = get,
    del = del,
    user = user
}