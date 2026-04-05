module("luci.controller.admin.modemsrv", package.seeall)

function index()
    -- 主菜单 "Modem"（挂载在 admin 下的 modem 子目录）
    entry({"admin", "modem"}, firstchild(), _("Modem"), 25).dependent = false

    -- 5Gmodem 页面（iframe 嵌入式 modemserver WebUI）
    entry({"admin", "modem", "5Gmodem"}, template("modemsrv/5Gmodem"), _("综合平台"), 1).dependent = false

    -- 自动验证（被 modemserver 调用）
    entry({"admin", "modem", "autoverify"}, call("AutoverifyCtrl"), nil).leaf = true

    -- 模组信息查询（被 5Gmodeminfo.htm 的 XHR 调用）
    entry({"admin", "modem", "qmodem", "modem_ctrl"}, call("ModemCtrl"), nil).leaf = true

    -- 模组配置列表（被 5Gmodeminfo.htm 的 XHR 调用）
    entry({"admin", "modem", "qmodem", "get_modem_cfg"}, call("GetModemCfg"), nil).leaf = true
end

function AutoverifyCtrl()
    luci.http.prepare_content("application/json")
    luci.http.write_json({})
end

-- 转发模组信息请求到 modemserver (端口 8080)
function ModemCtrl()
    luci.http.prepare_content("application/json")
    local cfg = luci.http.formvalue("cfg") or ""
    local action = luci.http.formvalue("action") or "info"

    local ok, result = pcall(function()
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        local json = require("cjson")
        local response = {}
        local url = "http://127.0.0.1:8080/api/modem/" .. action .. "?cfg=" .. cfg
        local _, code = http.request{url = url, sink = ltn12.sink.table(response)}
        if code == 200 then
            return json.decode(table.concat(response))
        end
        return nil
    end)

    if ok and result then
        luci.http.write_json(result)
    else
        luci.http.write_json({})
    end
end

-- 转发模组配置列表请求到 modemserver
function GetModemCfg()
    luci.http.prepare_content("application/json")

    local ok, result = pcall(function()
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

    if ok and result then
        luci.http.write_json(result)
    else
        luci.http.write_json({cfgs = {}})
    end
end
