module("luci.controller.modemserver", package.seeall)
local http = require "luci.http"
local io = require "io"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local nixio = require "nixio"
local util = require "luci.util"
local json = require("luci.jsonc")
uci = luci.model.uci.cursor()
-- 配置参数 - 根据实际情况修改
function index()
	entry({"admin", "modem"}, firstchild(), _("Modem"), 25).dependent=false
    -- 主菜单直接指向模板，不创建子菜单
    entry({"admin", "modem","5Gmodem"}, template("modemserver/5Gmodem"), luci.i18n.translate("综合平台"), 1).dependent = false
	entry({"admin", "modem", "autoverify"}, call("AutoverifyCtrl"), nil).leaf = true

end
-- 自动验证接口
function AutoverifyCtrl()
	local result = {}
	luci.http.prepare_content("application/json")
	luci.http.write(result)
end