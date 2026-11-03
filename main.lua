local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local SpinWidget = require("ui/widget/spinwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local _ = require("gettext")

local SETTINGS_PREFIX = "twenty_twenty_twenty_"
local ENABLED_KEY = SETTINGS_PREFIX .. "enabled"
local INTERVAL_KEY = SETTINGS_PREFIX .. "interval_minutes"
local REST_KEY = SETTINGS_PREFIX .. "rest_seconds"
local DOC_ONLY_KEY = SETTINGS_PREFIX .. "is_doc_only"
local DARK_MODE_KEY = SETTINGS_PREFIX .. "dark_mode"

local DEFAULT_ENABLED = true
local DEFAULT_INTERVAL_MINUTES = 20
local DEFAULT_REST_SECONDS = 20
local DEFAULT_DOC_ONLY = true
local DEFAULT_DARK_MODE = false

local MIN_INTERVAL_MINUTES = 1
local MAX_INTERVAL_MINUTES = 180
local MIN_REST_SECONDS = 1
local MAX_REST_SECONDS = 300

local Screen = Device.screen
local active_instance = nil

local function readSetting(key, default)
    local value = G_reader_settings:readSetting(key)
    if value == nil then
        return default
    end
    return value
end

local function clampNumber(value, min_value, max_value, default)
    value = tonumber(value) or default
    if value < min_value then
        return min_value
    elseif value > max_value then
        return max_value
    end
    return value
end

local function isDarkModeActive()
    local manual_setting = G_reader_settings:readSetting(DARK_MODE_KEY)
    if manual_setting ~= nil then
        return manual_setting == true
    end
    if G_reader_settings and G_reader_settings:isTrue("night_mode") then
        return true
    end
    return false
end

local RestOverlay = InputContainer:extend{
    name = "twenty_twenty_twenty_rest_overlay",
    covers_fullscreen = true,
    disable_double_tap = true,
}

function RestOverlay:init()
    self.remaining = math.max(0, tonumber(self.seconds) or DEFAULT_REST_SECONDS)
    self.dimen = Screen:getSize()
    self.key_events = {
        Close = { { Device.input.group.Back } },
    }
    self:_buildContent()
end

function RestOverlay:_buildContent()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    local font_size = math.floor(screen_h * 0.18)
    local area_w = math.floor(screen_w * 0.65)
    local area_h = math.floor(font_size * 1.7)
    
    -- Fixed color mapping: When dark mode is active, use Black background with White text
    local is_dark = isDarkModeActive()
    local bg_color = is_dark and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE
    local fg_color = is_dark and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK

    self.countdown_dimen = Geom:new{
        x = math.floor((screen_w - area_w) / 2),
        y = math.floor((screen_h - area_h) / 2),
        w = area_w,
        h = area_h,
    }
    self.countdown_text = TextWidget:new{
        text = tostring(self.remaining),
        face = Font:getFace("cfont", font_size),
        bold = true,
        fgcolor = fg_color,
    }
    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = bg_color,
        dimen = self.dimen,
        CenterContainer:new{
            dimen = self.dimen,
            FrameContainer:new{
                bordersize = 0,
                padding = 0,
                margin = 0,
                background = bg_color,
                dimen = Geom:new{ w = area_w, h = area_h },
                CenterContainer:new{
                    dimen = Geom:new{ w = area_w, h = area_h },
                    self.countdown_text,
                },
            },
        },
    }
end

function RestOverlay:onShow()
    self:_scheduleTick()
end

function RestOverlay:_scheduleTick()
    if self.remaining <= 0 then
        self:_finish()
        return
    end
    if self._tick_timer then
        UIManager:unschedule(self._tick_timer)
    end
    self._tick_timer = UIManager:scheduleIn(1, function()
        self._tick_timer = nil
        self.remaining = self.remaining - 1
        self.countdown_text:setText(tostring(self.remaining))
        UIManager:setDirty(self, function()
            return "fast", self.countdown_dimen
        end)
        if self.remaining <= 0 then
            self._tick_timer = UIManager:scheduleIn(1, function()
                self._tick_timer = nil
                self:_finish()
            end)
        else
            self:_scheduleTick()
        end
    end)
end

function RestOverlay:_finish()
    if self._closed then
        return
    end
    self._closed = true
    UIManager:close(self)
    if self.on_done then
        self.on_done()
    end
end

function RestOverlay:onClose()
    self:_finish()
    return true
end

function RestOverlay:onCloseWidget()
    if self._tick_timer then
        UIManager:unschedule(self._tick_timer)
        self._tick_timer = nil
    end
    UIManager:setDirty(nil, "full")
end

local TwentyTwentyTwenty = WidgetContainer:extend{
    name = "20-20-20",
    is_doc_only = false,
}

function TwentyTwentyTwenty:init()
    if active_instance and active_instance ~= self then
        active_instance:shutdown()
    end
    active_instance = self
    self._timer_generation = 0
    self._session_run_count = 0
    self._remaining_seconds = nil
    self._timer_start_time = nil
    self._total_delay_seconds = nil
    self.ui.menu:registerToMainMenu(self)
    self:_migrateDefaults()
    
    if not self:isDocOnly() and self:isEnabled() then
        self:startTimer()
        logger.info("20-20-20: Global mode initialized, timer started.")
    end
end

function TwentyTwentyTwenty:_migrateDefaults()
    if G_reader_settings:readSetting(ENABLED_KEY) == nil then
        G_reader_settings:saveSetting(ENABLED_KEY, DEFAULT_ENABLED)
    end
    if G_reader_settings:readSetting(INTERVAL_KEY) == nil then
        G_reader_settings:saveSetting(INTERVAL_KEY, DEFAULT_INTERVAL_MINUTES)
    end
    if G_reader_settings:readSetting(REST_KEY) == nil then
        G_reader_settings:saveSetting(REST_KEY, DEFAULT_REST_SECONDS)
    end
    if G_reader_settings:readSetting(DOC_ONLY_KEY) == nil then
        G_reader_settings:saveSetting(DOC_ONLY_KEY, DEFAULT_DOC_ONLY)
    end
end

function TwentyTwentyTwenty:isEnabled()
    return readSetting(ENABLED_KEY, DEFAULT_ENABLED) ~= false
end

function TwentyTwentyTwenty:isDocOnly()
    local val = readSetting(DOC_ONLY_KEY, DEFAULT_DOC_ONLY)
    return val ~= false
end

function TwentyTwentyTwenty:getIntervalMinutes()
    return clampNumber(
        readSetting(INTERVAL_KEY, DEFAULT_INTERVAL_MINUTES),
        MIN_INTERVAL_MINUTES,
        MAX_INTERVAL_MINUTES,
        DEFAULT_INTERVAL_MINUTES
    )
end

function TwentyTwentyTwenty:getRestSeconds()
    return clampNumber(
        readSetting(REST_KEY, DEFAULT_REST_SECONDS),
        MIN_REST_SECONDS,
        MAX_REST_SECONDS,
        DEFAULT_REST_SECONDS
    )
end

function TwentyTwentyTwenty:getSessionRunCount()
    return self._session_run_count or 0
end

function TwentyTwentyTwenty:saveIntervalMinutes(value)
    G_reader_settings:saveSetting(
        INTERVAL_KEY,
        clampNumber(value, MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES, DEFAULT_INTERVAL_MINUTES)
    )
end

function TwentyTwentyTwenty:saveRestSeconds(value)
    G_reader_settings:saveSetting(
        REST_KEY,
        clampNumber(value, MIN_REST_SECONDS, MAX_REST_SECONDS, DEFAULT_REST_SECONDS)
    )
end

function TwentyTwentyTwenty:startTimer(custom_delay)
    self:stopTimer()
    if not self:isEnabled() then
        return
    end

    self._timer_generation = (self._timer_generation or 0) + 1
    local timer_generation = self._timer_generation
    
    local delay = custom_delay or (self:getIntervalMinutes() * 60)
    self._total_delay_seconds = delay
    self._timer_start_time = os.time()
    
    self._interval_timer = UIManager:scheduleIn(delay, function()
        if timer_generation ~= self._timer_generation then
            return
        end
        self._interval_timer = nil
        self._timer_start_time = nil
        self._remaining_seconds = nil
        self:showRestOverlay()
    end)
    logger.info("20-20-20: scheduled rest overlay in", delay, "seconds")
end

function TwentyTwentyTwenty:stopTimer()
    if self._interval_timer and self._timer_start_time and self._total_delay_seconds then
        local elapsed = os.time() - self._timer_start_time
        self._remaining_seconds = math.max(1, self._total_delay_seconds - elapsed)
    end

    self._timer_generation = (self._timer_generation or 0) + 1
    if self._interval_timer then
        UIManager:unschedule(self._interval_timer)
        self._interval_timer = nil
    end
end

function TwentyTwentyTwenty:showRestOverlay()
    if not self:isEnabled() then
        return
    end
    if self._rest_overlay then
        return
    end
    
    self._session_run_count = (self._session_run_count or 0) + 1
    self._remaining_seconds = nil
    self._timer_start_time = nil

    self._rest_overlay = RestOverlay:new{
        seconds = self:getRestSeconds(),
        on_done = function()
            self._rest_overlay = nil
            self:startTimer()
        end,
    }
    UIManager:show(self._rest_overlay)
end

function TwentyTwentyTwenty:shutdown()
    self:stopTimer()
    self._remaining_seconds = nil
    self._timer_start_time = nil
    if self._rest_overlay then
        self._rest_overlay.on_done = nil
        UIManager:close(self._rest_overlay)
        self._rest_overlay = nil
    end
end

function TwentyTwentyTwenty:onReaderReady()
    if self:isDocOnly() then
        self._session_run_count = 0
        self._remaining_seconds = nil
        self._timer_start_time = nil
        if self:isEnabled() then
            self:startTimer()
            logger.info("20-20-20: Reader ready, timer started.")
        end
    end
end

function TwentyTwentyTwenty:onCloseDoc()
    if self:isDocOnly() then
        self:shutdown()
        self._session_run_count = 0
        logger.info("20-20-20: Document closed, timer stopped.")
    end
end

-- Global KOReader Sleep / Power Events
function TwentyTwentyTwenty:onSuspend()
    self:stopTimer()
    logger.info("20-20-20: onSuspend triggered, timer paused with remaining:", self._remaining_seconds)
end

function TwentyTwentyTwenty:onResume()
    local active_condition = self:isDocOnly() and self.ui.document or not self:isDocOnly()
    if self:isEnabled() and active_condition then
        local delay = self._remaining_seconds or (self:getIntervalMinutes() * 60)
        self:startTimer(delay)
        logger.info("20-20-20: onResume triggered, timer resumed with delay:", delay)
    end
end

function TwentyTwentyTwenty:openIntervalPicker(touchmenu_instance)
    UIManager:show(SpinWidget:new{
        title_text = _("Rest interval"),
        info_text = _("Minutes between fullscreen reminders."),
        value = self:getIntervalMinutes(),
        value_min = MIN_INTERVAL_MINUTES,
        value_max = MAX_INTERVAL_MINUTES,
        value_step = 1,
        unit = _("min"),
        ok_text = _("Set"),
        cancel_text = _("Cancel"),
        default_value = DEFAULT_INTERVAL_MINUTES,
        callback = function(spin)
            self:saveIntervalMinutes(spin.value)
            self._remaining_seconds = nil
            local active_condition = self:isDocOnly() and self.ui.document or not self:isDocOnly()
            if self:isEnabled() and active_condition then
                self:startTimer()
            end
            if touchmenu_instance then
                touchmenu_instance:updateItems()
            end
        end,
    })
end

function TwentyTwentyTwenty:openRestPicker(touchmenu_instance)
    UIManager:show(SpinWidget:new{
        title_text = _("Rest countdown"),
        info_text = _("Seconds to keep the black rest screen visible."),
        value = self:getRestSeconds(),
        value_min = MIN_REST_SECONDS,
        value_max = MAX_REST_SECONDS,
        value_step = 1,
        unit = _("sec"),
        ok_text = _("Set"),
        cancel_text = _("Cancel"),
        default_value = DEFAULT_REST_SECONDS,
        callback = function(spin)
            self:saveRestSeconds(spin.value)
            if touchmenu_instance then
                touchmenu_instance:updateItems()
            end
        end,
    })
end

function TwentyTwentyTwenty:addToMainMenu(menu_items)
    menu_items.twenty_twenty_twenty = {
        text = _("20-20-20 Timer"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text_func = function()
                    return self:isEnabled() and _("Disable timer") or _("Enable timer")
                end,
                checked_func = function()
                    return self:isEnabled()
                end,
                callback = function(touchmenu_instance)
                    local enabled = not self:isEnabled()
                    G_reader_settings:saveSetting(ENABLED_KEY, enabled)
                    local active_condition = self:isDocOnly() and self.ui.document or not self:isDocOnly()
                    if enabled and active_condition then
                        self._remaining_seconds = nil
                        self:startTimer()
                    else
                        self:stopTimer()
                    end
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return _("Apply in reading only")
                end,
                checked_func = function()
                    return self:isDocOnly()
                end,
                callback = function(touchmenu_instance)
                    local doc_only = not self:isDocOnly()
                    G_reader_settings:saveSetting(DOC_ONLY_KEY, doc_only)
                    
                    if doc_only then
                        if not self.ui.document then
                            self:stopTimer()
                        end
                    else
                        if self:isEnabled() and not self._interval_timer then
                            self._remaining_seconds = nil
                            self:startTimer()
                        end
                    end

                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return _("Dark mode rest screen")
                end,
                checked_func = function()
                    return isDarkModeActive()
                end,
                callback = function(touchmenu_instance)
                    local current_dark = isDarkModeActive()
                    G_reader_settings:saveSetting(DARK_MODE_KEY, not current_dark)
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return string.format(_("Interval: %d min"), self:getIntervalMinutes())
                end,
                callback = function(touchmenu_instance)
                    self:openIntervalPicker(touchmenu_instance)
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return string.format(_("Countdown: %d sec"), self:getRestSeconds())
                end,
                callback = function(touchmenu_instance)
                    self:openRestPicker(touchmenu_instance)
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return string.format(_("Rest count: %d"), self:getSessionRunCount())
                end,
                callback = function(touchmenu_instance)
                    self._session_run_count = 0
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                info_text = _("Number of times the rest screen has appeared for this document session. Tap to reset."),
                keep_menu_open = true,
            },
            {
                text = _("Show rest screen now"),
                callback = function(touchmenu_instance)
                    self:stopTimer()
                    self._remaining_seconds = nil
                    self:showRestOverlay()
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
            },
        },
    }
end

function TwentyTwentyTwenty:onClose()
    if self:isDocOnly() then
        self:shutdown()
    end
    if active_instance == self then
        active_instance = nil
    end
end

return TwentyTwentyTwenty
