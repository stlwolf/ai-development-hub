-- WezTerm AI Mode: Event Handlers
--
-- .wezterm.lua に追加するイベントハンドラの参考実装。
-- user-var経由でシェルからWezTermのLuaレイヤに通知を送る。
--
-- 使い方:
--   1. この内容を .wezterm.lua の `return config` の前にコピー
--   2. シェルから: printf "\033]1337;SetUserVar=%s=%s\007" "ai_notify" "$(echo -n 'message' | base64)"
--
-- または .wezterm.lua で require する:
--   local ai_mode = require('ai-mode-events')
--   ai_mode.setup(config)

local wezterm = require 'wezterm'
local M = {}

function M.setup(_config)
  wezterm.on('user-var-changed', function(window, pane, name, value)
    if name == 'ai_notify' then
      local decoded = value
      local parts = {}
      for part in decoded:gmatch('[^|]+') do
        table.insert(parts, part)
      end

      local title = parts[1] or 'AI Mode'
      local body = parts[2] or ''
      local timeout = tonumber(parts[3]) or 4000

      window:toast_notification('WezTerm AI', title .. ': ' .. body, nil, timeout)
      wezterm.log_info('ai_notify: ' .. title .. ' - ' .. body)
    end

    if name == 'ai_status' then
      wezterm.log_info('ai_status: ' .. value)
    end
  end)
end

return M
