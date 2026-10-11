local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local SpinWidget = require("ui/widget/spinwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")

local _ = require("gettext")

local SETTINGS_PREFIX = "twenty_twenty_twenty_"
local INTERVAL_KEY = SETTINGS_PREFIX .. "interval_minutes"
local REST_KEY = SETTINGS_PREFIX .. "rest_seconds"

local DEFAULT_INTERVAL_MINUTES = 20
local DEFAULT_REST_SECONDS = 20

local MIN_INTERVAL_MINUTES = 1
local MAX_INTERVAL_MINUTES = 360
local MIN_REST_SECONDS = 1
local MAX_REST_SECONDS = 1800

local Screen = Device.screen
local active_instance = nil

local function readSetting(key, default)
    if not G_reader_settings then return default end
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

local RestOverlay = InputContainer:extend{
    name = "custom_eye_rest_overlay",
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

    local font_size = math.floor(screen_h * 0.15)
    local sub_font_size = math.floor(screen_h * 0.04)

    local is_night_mode = false
    if G_reader_settings and G_reader_settings:isTrue("night_mode") then
        is_night_mode = true
    elseif Screen.isNightMode and Screen:isNightMode() then
        is_night_mode = true
    end

    local bg_color = is_night_mode and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK
    local fg_color = is_night_mode and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE

    self.countdown_text = TextWidget:new{
        text = tostring(self.remaining),
        face = Font:getFace("cfont", font_size),
        bold = true,
        fgcolor = fg_color,
    }

    self.tip_text = TextWidget:new{
        text = _("Rest Eyes"),
        face = Font:getFace("cfont", sub_font_size),
        fgcolor = fg_color,
    }

    local group = VerticalGroup:new{
        align = "center",
        space = math.floor(screen_h * 0.03),
        self.countdown_text,
        self.tip_text,
    }

    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = bg_color,
        dimen = self.dimen,
        CenterContainer:new{
            dimen = self.dimen,
            group,
        },
    }
end

function RestOverlay:onShow()
    self:_scheduleTick()
end

function RestOverlay:_scheduleTick()
    if self._closed then return end

    if self.remaining <= 0 then
        self:_finish()
        return
    end

    if self._tick_timer then
        UIManager:unschedule(self._tick_timer)
    end

    self._tick_timer = UIManager:scheduleIn(1, function()
        self._tick_timer = nil
        if self._closed then return end

        self.remaining = self.remaining - 1
        self.countdown_text:setText(tostring(self.remaining))
        
        UIManager:setDirty(self, function()
            return "fast", self.dimen
        end)

        if self.remaining <= 0 then
            self:_finish()
        else
            self:_scheduleTick()
        end
    end)
end

function RestOverlay:_finish()
    if self._closed then return end
    self._closed = true
    if self._tick_timer then
        UIManager:unschedule(self._tick_timer)
        self._tick_timer = nil
    end
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
    self.ui.menu:registerToMainMenu(self)
    self:_migrateDefaults()
end

function TwentyTwentyTwenty:_migrateDefaults()
    if G_reader_settings:readSetting(INTERVAL_KEY) == nil then
        G_reader_settings:saveSetting(INTERVAL_KEY, DEFAULT_INTERVAL_MINUTES)
    end
    if G_reader_settings:readSetting(REST_KEY) == nil then
        G_reader_settings:saveSetting(REST_KEY, DEFAULT_REST_SECONDS)
    end
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

function TwentyTwentyTwenty:startSingleTimer(custom_delay)
    self:stopTimer()

    self._timer_generation = (self._timer_generation or 0) + 1
    local timer_generation = self._timer_generation
    local delay = custom_delay or (self:getIntervalMinutes() * 60)

    self._interval_timer = UIManager:scheduleIn(delay, function()
        if timer_generation ~= self._timer_generation then
            return
        end
        self._interval_timer = nil
        self:showRestOverlay()
    end)
    logger.info("EyeRestTimer: scheduled single rest timer in", delay, "seconds")
end

function TwentyTwentyTwenty:stopTimer()
    self._timer_generation = (self._timer_generation or 0) + 1
    if self._interval_timer then
        UIManager:unschedule(self._interval_timer)
        self._interval_timer = nil
    end
end

function TwentyTwentyTwenty:showRestOverlay()
    if self._rest_overlay then
        return
    end

    self._rest_overlay = RestOverlay:new{
        seconds = self:getRestSeconds(),
        on_done = function()
            self._rest_overlay = nil
            self:promptCompletionOptions()
        end,
    }
    UIManager:show(self._rest_overlay)
end

function TwentyTwentyTwenty:promptCompletionOptions()
    UIManager:show(ConfirmBox:new{
        text = _("Rest finished! What would you like to do next?"),
        ok_text = _("Start Next Timer"),
        cancel_text = _("Continue Reading (No Timer)"),
        callback = function()
            self:startSingleTimer()
            UIManager:show(InfoMessage:new{
                text = string.format(_("Eye rest timer started for %d minutes."), self:getIntervalMinutes()),
                timeout = 3,
            })
        end,
        cancel_callback = function()
            self:stopTimer()
        end,
    })
end

function TwentyTwentyTwenty:shutdown()
    self:stopTimer()
    if self._rest_overlay then
        self._rest_overlay.on_done = nil
        UIManager:close(self._rest_overlay)
        self._rest_overlay = nil
    end
end

function TwentyTwentyTwenty:openIntervalPicker(touchmenu_instance)
    UIManager:show(SpinWidget:new{
        title_text = _("Rest interval"),
        info_text = _("Minutes before fullscreen rest reminder."),
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
            if touchmenu_instance then
                touchmenu_instance:updateItems()
            end
        end,
    })
end

function TwentyTwentyTwenty:openRestPicker(touchmenu_instance)
    UIManager:show(SpinWidget:new{
        title_text = _("Rest duration"),
        info_text = _("Seconds to keep the rest screen active."),
        value = self:getRestSeconds(),
        value_min = MIN_REST_SECONDS,
        value_max = MAX_REST_SECONDS,
        value_step = 5,
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
        text_func = function()
            return string.format(_("Eye Rest Timer (%dm / %ds)"), self:getIntervalMinutes(), self:getRestSeconds())
        end,
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("Start one-time timer"),
                callback = function(touchmenu_instance)
                    self:startSingleTimer()
                    UIManager:show(InfoMessage:new{
                        text = string.format(_("Eye rest timer started for %d minutes."), self:getIntervalMinutes()),
                        timeout = 3,
                    })
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                keep_menu_open = true,
            },
            {
                text = _("Stop one-time timer"),
                callback = function(touchmenu_instance)
                    self:stopTimer()
                    UIManager:show(InfoMessage:new{
                        text = _("Eye rest timer stopped."),
                        timeout = 2,
                    })
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return string.format(_("Set Interval (%d min)"), self:getIntervalMinutes())
                end,
                callback = function(touchmenu_instance)
                    self:openIntervalPicker(touchmenu_instance)
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return string.format(_("Set Rest Duration (%d sec)"), self:getRestSeconds())
                end,
                callback = function(touchmenu_instance)
                    self:openRestPicker(touchmenu_instance)
                end,
                keep_menu_open = true,
            },
            {
                text = _("Quick Presets"),
                sub_item_table = {
                    {
                        text = _("15 Min Interval / 20 Sec Rest"),
                        callback = function(touchmenu_instance)
                            self:saveIntervalMinutes(15)
                            self:saveRestSeconds(20)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    },
                    {
                        text = _("20 Min Interval / 20 Sec Rest (20-20-20 Rule)"),
                        callback = function(touchmenu_instance)
                            self:saveIntervalMinutes(20)
                            self:saveRestSeconds(20)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    },
                    {
                        text = _("30 Min Interval / 30 Sec Rest"),
                        callback = function(touchmenu_instance)
                            self:saveIntervalMinutes(30)
                            self:saveRestSeconds(30)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    },
                    {
                        text = _("45 Min Interval / 60 Sec Rest"),
                        callback = function(touchmenu_instance)
                            self:saveIntervalMinutes(45)
                            self:saveRestSeconds(60)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    },
                    {
                        text = _("60 Min Interval / 5 Min Rest (Pomodoro Break)"),
                        callback = function(touchmenu_instance)
                            self:saveIntervalMinutes(60)
                            self:saveRestSeconds(300)
                            if touchmenu_instance then touchmenu_instance:updateItems() end
                        end,
                    },
                },
            },
            {
                text = _("Show rest screen now"),
                callback = function()
                    self:stopTimer()
                    self:showRestOverlay()
                end,
            },
        },
    }
end

function TwentyTwentyTwenty:onClose()
    self:shutdown()
    if active_instance == self then
        active_instance = nil
    end
end

return TwentyTwentyTwenty
