-- lua/custom/widgets/weather.lua
local M = {}

-- ---- config ----
M.opts = {
  city = 'Stavanger',
  query = '1Q&lang=en', -- 1 = current+today (we'll slice), Q = quiet, T = no color
  slice = { from = 6, to = 15 }, -- keep these lines from wttr output (tunes which box to show)
  zindex = 200,
  top_row = 0, -- anchored at top
  center = true, -- center horizontally
  refresh_ms = 0, -- 0 = only on demand; set e.g. 15*60*1000 to auto-refresh every 15m
}

-- ---- state ----
local buf, win
local text_cache = "Loading today's forecast…"
local timer

-- ---- helpers ----
local function split_lines(s)
  local t = {}
  for l in (s or ''):gmatch '[^\r\n]+' do
    t[#t + 1] = l
  end
  if #t == 0 then
    t[1] = ''
  end
  return t
end

local function max_display_width(lines)
  local w = 0
  for _, l in ipairs(lines) do
    local lw = vim.fn.strdisplaywidth(l)
    if lw > w then
      w = lw
    end
  end
  return w
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
    vim.api.nvim_set_option_value('filetype', 'text', { buf = buf })
  end

  local lines = split_lines(text_cache)
  local width = max_display_width(lines)
  local height = #lines

  local col = 0
  if M.opts.center then
    col = math.max(0, math.floor((vim.o.columns - width) / 2))
  end

  local cfg = {
    relative = 'editor',
    row = M.opts.top_row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    focusable = false,
    zindex = M.opts.zindex,
    -- border = "rounded", -- uncomment if you want an extra border
  }

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, cfg)
  else
    win = vim.api.nvim_open_win(buf, false, cfg)
    vim.api.nvim_set_option_value('wrap', false, { win = win })
    vim.api.nvim_set_option_value('cursorline', false, { win = win })
    vim.api.nvim_set_option_value('winhl', 'Normal:MiniStarterHeader,FloatBorder:FloatBorder', { win = win })
  end

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ok, baleia = pcall(require, 'baleia')
  if ok then
    local painter = baleia.setup { line_starts_at = 1 }
    painter.once(buf) -- colorize buffer and remove ANSI sequences
  end
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
end

-- ---- public API ----
function M.show()
  render()
end

function M.hide()
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  win = nil
end

function M.is_visible()
  return win and vim.api.nvim_win_is_valid(win)
end

function M.refresh()
  if vim.fn.executable 'curl' ~= 1 then
    text_cache = 'curl not found'
    vim.schedule(render)
    return
  end
  local url = ('https://wttr.in/%s?%s'):format(M.opts.city, M.opts.query)
  vim.system({ 'curl', '-fsSL', url }, { text = true, timeout = 4000 }, function(res)
    if res.code ~= 0 or not res.stdout or #res.stdout == 0 then
      return
    end
    local lines = vim.split(res.stdout, '\n')
    local from, to = M.opts.slice.from, M.opts.slice.to
    local picked = {}
    for i = from, to do
      if lines[i] then
        picked[#picked + 1] = lines[i]
      end
    end
    text_cache = table.concat(picked, '\n')
    vim.schedule(render)
  end)
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', M.opts, opts or {})
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  if M.opts.refresh_ms and M.opts.refresh_ms > 0 then
    timer = vim.loop.new_timer()
    timer:start(
      0,
      M.opts.refresh_ms,
      vim.schedule_wrap(function()
        M.refresh()
      end)
    )
  end

  -- recentre on resize
  vim.api.nvim_create_autocmd('VimResized', {
    group = vim.api.nvim_create_augroup('WeatherWidgetAuto', { clear = true }),
    callback = function()
      if win and vim.api.nvim_win_is_valid(win) then
        render()
      end
    end,
  })
end

return M
