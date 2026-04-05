module("luci.controller.admin.modemsrv", package.seeall)

function index()
    entry({"admin", "modem"}, firstchild(), _("Modem"), 25).dependent = false
    entry({"admin", "modem", "5Gmodem"}, template("modemsrv/5Gmodem"), _("综合平台"), 1).dependent = false
    entry({"admin", "modem", "autoverify"}, call("AutoverifyCtrl"), nil).leaf = true
    entry({"admin", "modem", "qmodem", "modem_ctrl"}, call("ModemCtrl"), nil).leaf = true
    entry({"admin", "modem", "qmodem", "get_modem_cfg"}, call("GetModemCfg"), nil).leaf = true
end

function AutoverifyCtrl()
    local result = {}
    luci.http.prepare_content("application/json")
    luci.http.write(result)
end

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
