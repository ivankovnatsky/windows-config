-- Create a table in the global scope to hold our functions
_G.system_appearance = {}

-- Function to check Windows appearance
local function get_windows_appearance()
  -- Check Windows registry for current theme using PowerShell
  local handle = io.popen('powershell.exe -Command "Get-ItemProperty -Path HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize -Name AppsUseLightTheme | Select-Object -ExpandProperty AppsUseLightTheme"')
  if handle then
    local result = handle:read("*a")
    handle:close()
    -- AppsUseLightTheme: 1 = light, 0 = dark
    if result and result:match("0") then
      return "dark"
    else
      return "light"
    end
  end
  return "light" -- Default to light if we can't determine
end

-- Variable to store the current appearance
local current_appearance = get_windows_appearance()

-- Function to set the background
local function set_background()
  vim.o.background = current_appearance
end

-- Function to check and update appearance asynchronously
function _G.system_appearance.check_appearance()
  vim.schedule(function()
    local new_appearance = get_windows_appearance()
    if new_appearance ~= current_appearance then
      current_appearance = new_appearance
      set_background()
      print("Appearance changed to: " .. new_appearance)
    end
  end)
end

-- Set up timer for periodic checking
local check_interval = 5000 -- Check every 5 seconds (adjust as needed)
local timer = vim.loop.new_timer()
timer:start(0, check_interval, vim.schedule_wrap(_G.system_appearance.check_appearance))

-- Set initial background
set_background()

-- Set up the autocommand
vim.cmd([[
  augroup SystemAppearance
    autocmd!
    autocmd FocusGained * lua _G.system_appearance.check_appearance()
  augroup END
]])