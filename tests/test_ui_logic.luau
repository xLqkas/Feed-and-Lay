--!strict
-- Self-check for src/client/UI/Logic.luau. Run from the repo root: lune run tests/test_ui_logic.luau
local Logic = require("../src/client/UI/Logic")

-- Layout breakpoints (acceptance sizes from design-v3 VS-4)
local phone = Logic.layoutFor(375, 667)
assert(phone.compact, "phone portrait must be compact")
assert(phone.toastMax == 2, "phone shows 2 toasts")
assert(math.abs(phone.scale - 667 / 1080) < 1e-9, "phone scale = height / 1080")
assert(phone.touchMin * phone.scale >= 56, "phone touch target >= 56 real px")
assert(phone.panelWidth <= phone.refWidth and phone.panelHeight <= phone.refHeight, "phone panel fits")
assert(phone.toastWidth <= phone.refWidth, "phone toast fits")

local landscape = Logic.layoutFor(667, 375)
assert(landscape.compact and landscape.scale == 0.55, "landscape phone clamps scale to 0.55")
assert(landscape.panelHeight <= landscape.refHeight, "landscape panel fits")

local pc = Logic.layoutFor(1920, 1080)
assert(not pc.compact and pc.scale == 1 and pc.toastMax == 3, "1080p PC is not compact")
assert(pc.panelWidth == 900 and pc.panelHeight == 620, "PC panel 900 x 620")
assert(Logic.layoutFor(3840, 2160).scale == 1.2, "4K clamps scale to 1.2")

local tablet = Logic.layoutFor(768, 1024)
assert(not tablet.compact and tablet.panelWidth <= tablet.refWidth, "tablet panel never wider than screen")
assert(Logic.layoutFor(699, 900).compact and Logic.layoutFor(1280, 499).compact, "breakpoints X < 700 or Y < 500")
assert(not Logic.layoutFor(700, 500).compact, "700 x 500 is not compact")

-- Number format
assert(Logic.formatNumber(0) == "0", "formatNumber(0)")
assert(Logic.formatNumber(999) == "999", "formatNumber(999)")
assert(Logic.formatNumber(1000) == "1K", "formatNumber(1000)")
assert(Logic.formatNumber(1234) == "1.2K", "formatNumber(1234)")
assert(Logic.formatNumber(45300) == "45.3K", "formatNumber(45300)")
assert(Logic.formatNumber(150000) == "150K", "formatNumber(150000)")
assert(Logic.formatNumber(999999) == "999K", "formatNumber(999999)")
assert(Logic.formatNumber(1200000) == "1.2M", "formatNumber(1200000)")
assert(Logic.formatNumber(36000000) == "36M", "formatNumber(36000000)")
assert(Logic.formatNumber(-1500) == "-1.5K", "formatNumber(-1500)")

-- Panel manager state: one panel at a time
local state = Logic.newPanelState()
assert(Logic.openPanel(state, "Upgrades") == nil, "first open closes nothing")
assert(Logic.openPanel(state, "Upgrades") == nil, "reopening the same panel closes nothing")
assert(Logic.openPanel(state, "Pets") == "Upgrades", "opening Pets closes Upgrades")
assert(not Logic.closePanel(state, "Upgrades"), "closing a hidden panel is a no-op")
assert(Logic.closePanel(state, "Pets") and state.open == nil, "closing the open panel clears state")

print("PASS test_ui_logic")
