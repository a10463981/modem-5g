module("luci.controller.admin.modemsrv", package.seeall)

function index()
    entry({"admin", "modem"}, firstchild(), _("Modem"), 25).dependent = false
    entry({"admin", "modem", "5Gmodem"}, template("modemserver/5Gmodem"), _("综合平台"), 1).dependent = false
    entry({"admin", "modem", "autoverify"}, call("AutoverifyCtrl"), nil).leaf = true
    entry({"admin", "modemserver", "qmodem", "modem_ctrl"}, call("ModemCtrl"), nil).leaf = true
    entry({"admin", "modemserver", "qmodem", "get_modem_cfg"}, call("GetModemCfg"), nil).leaf = true
end

function AutoverifyCtrl()
    luci.http.prepare_content("application/json")
    luci.http.write_json({})
end

-- 获取模组信息（通过 LuCI ixml HTTP 客户端转发请求到 modemserver）
function ModemCtrl()
    luci.http.prepare_content("application/json")
    local cfg = luci.http.formvalue("cfg") or ""
    local action = luci.http.formvalue("action") or "info"
    
    local status, data = pcall(function()
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        local json = require("cjson")
        local response = {}
        local url = "http://127.0.0.1:8080/api/modem/" .. action .. "?cfg=" .. cfg
        local _, code = http.request{
            url = url,
            sink = ltn12.sink.table(response)
        }
        if code == 200 then
            return json.decode(table.concat(response))
        end
        return nil
    end)
    
    if status and data then
        luci.http.write_json(data)
    else
        luci.http.write_json({})
    end
end

-- 获取模组配置列表
function GetModemCfg()
    luci.http.prepare_content("application/json")
    
    local status, data = pcall(function()
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        local json = require("cjson")
        local response = {}
        local _, code = http.request{
            url = "http://127.0.0.1:8080/api/modem/cfgs",
            sink = ltn12.sink.table(response)
        }
        if code == 200 then
            return json.decode(table.concat(response))
        end
        return nil
    end)
    
    if status and data then
        luci.http.write_json(data)
    else
        luci.http.write_json({cfgs = {}})
    end
end
