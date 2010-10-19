local pcall, dofile, _G = pcall, dofile, _G

module "luci.version"

if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
	distname    = ""
	distversion = _G.DISTRIB_DESCRIPTION
else
	distname    = "OpenWrt Firmware"
	distversion = "Backfire (r22711)"
end

luciname    = "LuCI 0.9 Branch"
luciversion = "0.9+svn6240"
