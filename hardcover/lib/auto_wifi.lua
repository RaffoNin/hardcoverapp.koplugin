local SETTING = require("hardcover/lib/constants/settings")

local Device = require("device")
local logger = require("logger")

local NetworkMgr = require("ui/network/manager")

local AutoWifi = {
  connection_pending = false
}
AutoWifi.__index = AutoWifi

function AutoWifi:new(o)
  return setmetatable(o, self)
end

function AutoWifi:withWifi(callback)
  logger.warn(
    "HARDCOVER AutoWifi: withWifi() START",
    "wifi_on =", NetworkMgr:isWifiOn(),
    "pending =", NetworkMgr.pending_connection,
    "connection_pending =", self.connection_pending,
    "airplanemode =", G_reader_settings:nilOrFalse("airplanemode"),
    "auto_wifi_setting =", self.settings:readSetting(SETTING.ENABLE_WIFI),
    "has_wifi_restore =", Device:hasWifiRestore()
  )

  if NetworkMgr:isWifiOn() then
    logger.warn("HARDCOVER AutoWifi: WiFi already ON -> running callback")

    callback(false)

    logger.warn("HARDCOVER AutoWifi: withWifi() END - WiFi was already ON")
    return
  end

  if not self.settings:readSetting(SETTING.ENABLE_WIFI) then
    logger.warn("HARDCOVER AutoWifi: NOT enabling WiFi - setting is disabled")
    return
  end

  if NetworkMgr.pending_connection then
    logger.warn("HARDCOVER AutoWifi: NOT enabling WiFi - NetworkMgr.pending_connection is TRUE")
    return
  end

  if not Device:hasWifiRestore() then
    logger.warn("HARDCOVER AutoWifi: NOT enabling WiFi - device hasWifiRestore() is FALSE")
    return
  end

  if G_reader_settings:nilOrFalse("airplanemode") == false then
    logger.warn("HARDCOVER AutoWifi: NOT enabling WiFi - airplane mode is ON")
    return
  end

  logger.warn("HARDCOVER AutoWifi: ALL CONDITIONS PASSED")

  local original_on = NetworkMgr.wifi_was_on

  logger.warn(
    "HARDCOVER AutoWifi: original wifi_was_on =",
    original_on
  )

  self.connection_pending = true

  logger.warn("HARDCOVER AutoWifi: calling NetworkMgr:restoreWifiAsync()")

  NetworkMgr:restoreWifiAsync()

  logger.warn("HARDCOVER AutoWifi: restoreWifiAsync() returned")

  logger.warn("HARDCOVER AutoWifi: scheduling connectivity check")

  NetworkMgr:scheduleConnectivityCheck(function()
    logger.warn(
      "HARDCOVER AutoWifi: CONNECTIVITY CHECK CALLBACK",
      "wifi_on =", NetworkMgr:isWifiOn(),
      "pending =", NetworkMgr.pending_connection,
      "connection_pending =", self.connection_pending,
      "wifi_was_on =", NetworkMgr.wifi_was_on
    )

    -- restore original "was on" state to prevent wifi being
    -- restored automatically after suspend
    NetworkMgr.wifi_was_on = original_on
    G_reader_settings:saveSetting("wifi_was_on", original_on)

    logger.warn(
      "HARDCOVER AutoWifi: restored wifi_was_on to",
      original_on
    )

    self.connection_pending = false

    logger.warn("HARDCOVER AutoWifi: running Hardcover callback")

    callback(true)

    logger.warn("HARDCOVER AutoWifi: Hardcover callback finished")

    -- TODO: schedule turn off wifi, debounce
    logger.warn("HARDCOVER AutoWifi: calling wifiDisableSilent()")

    self:wifiDisableSilent()

    logger.warn("HARDCOVER AutoWifi: connectivity callback finished")
  end)

  logger.warn("HARDCOVER AutoWifi: withWifi() END - waiting for connectivity")
end

function AutoWifi:wifiDisableSilent()
  logger.warn(
    "HARDCOVER AutoWifi: wifiDisableSilent() START",
    "wifi_on =", NetworkMgr:isWifiOn(),
    "wifi_was_on =", NetworkMgr.wifi_was_on
  )

  NetworkMgr:turnOffWifi(function()
    logger.warn(
      "HARDCOVER AutoWifi: turnOffWifi() CALLBACK",
      "wifi_on =", NetworkMgr:isWifiOn()
    )

    -- explicitly disable wifi was on
    NetworkMgr.wifi_was_on = false
    G_reader_settings:saveSetting("wifi_was_on", false)

    logger.warn(
      "HARDCOVER AutoWifi: WiFi disabled, wifi_was_on set to false"
    )
  end)
end

function AutoWifi:wifiPrompt(callback)
  logger.warn(
    "HARDCOVER AutoWifi: wifiPrompt() START",
    "wifi_on =", NetworkMgr:isWifiOn(),
    "airplanemode =", G_reader_settings:isTrue("airplanemode"),
    "auto_wifi_setting =", self.settings:readSetting(SETTING.ENABLE_WIFI)
  )

  if NetworkMgr:isWifiOn() then
    logger.warn("HARDCOVER AutoWifi: wifiPrompt() - WiFi already ON")

    if callback then
      callback(false)
    end

    return
  end

  if G_reader_settings:isTrue("airplanemode") then
    logger.warn("HARDCOVER AutoWifi: wifiPrompt() - airplane mode ON")
    return
  end

  local network_callback = callback and function()
    logger.warn("HARDCOVER AutoWifi: wifiPrompt() network callback")

    callback(true)
  end or nil

  if self.settings:readSetting(SETTING.ENABLE_WIFI) then
    logger.warn(
      "HARDCOVER AutoWifi: wifiPrompt() - using turnOnWifiAndWaitForConnection()"
    )

    NetworkMgr:turnOnWifiAndWaitForConnection(network_callback)
  else
    logger.warn(
      "HARDCOVER AutoWifi: wifiPrompt() - using promptWifiOn()"
    )

    NetworkMgr:promptWifiOn(network_callback)
  end
end

function AutoWifi:wifiDisablePrompt()
  logger.warn(
    "HARDCOVER AutoWifi: wifiDisablePrompt() START",
    "auto_wifi_setting =", self.settings:readSetting(SETTING.ENABLE_WIFI),
    "has_wifi_restore =", Device:hasWifiRestore(),
    "wifi_on =", NetworkMgr:isWifiOn()
  )

  if self.settings:readSetting(SETTING.ENABLE_WIFI)
      and Device:hasWifiRestore() then

    logger.warn(
      "HARDCOVER AutoWifi: wifiDisablePrompt() - using wifiDisableSilent()"
    )

    self:wifiDisableSilent()
  else
    logger.warn(
      "HARDCOVER AutoWifi: wifiDisablePrompt() - using toggleWifiOff()"
    )

    NetworkMgr:toggleWifiOff()
  end
end

return AutoWifi