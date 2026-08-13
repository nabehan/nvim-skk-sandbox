-- ~/.config/nvim/lua/my/utils/skk.lua
-- skk.nvim（https://github.com/nabehan/skk.nvim）の設定。
-- vim-skk/skkeleton からの移行（旧 lua/my/utils/skkeleton.lua）。
-- skk.nvim は denops に依存しない単一プロセスの Lua 実装なので、
-- skkeleton.lua にあった DenopsReady 待ちのフォールバックは不要。

local skk = require("skk")
local dict = require("skk.dict")

skk.setup({
  -- skkeleton.lua の skkServerHost/skkServerPort を踏襲
  skkserv = { host = "127.0.0.1", port = 1178, encoding = "euc-jp" },

  -- skkeleton.lua の userDictionary を踏襲
  user_dictionary = vim.fn.expand("~/.local/share/skk/SKK-JISYO.user"),

  -- skkeleton.lua の eggLikeNewline = true を踏襲
  egg_like_newline = true,

  -- blink.cmp ネイティブソース（lua/skk/blink_source.lua）の設定。
  -- ソース自体の登録は lua/my/cmp/blink.lua 側で行う。
  blink = { max_items = 50 },
})

-- ローカル辞書（skkeleton.lua の globalDictionaries 相当）。
-- 1件目は load_dictionary_async()（唯一のソースとして設定）、
-- 2件目以降は add_dictionary_async()（追加登録。優先順位は登録順）。
dict.load_dictionary_async("/usr/local/share/skk/SKK-JISYO.edict2", "utf-8", function(ok, err)
  if not ok then
    vim.notify("skk.nvim: SKK-JISYO.edict2 の読み込みに失敗しました: " .. tostring(err), vim.log.levels.WARN)
  end
end)
dict.add_dictionary_async("/usr/local/share/skk/SKK-JISYO.emoji", "utf-8", function(ok, err)
  if not ok then
    vim.notify("skk.nvim: SKK-JISYO.emoji の読み込みに失敗しました: " .. tostring(err), vim.log.levels.WARN)
  end
end)
dict.add_dictionary_async("/usr/local/share/skk/SKK-JISYO.emoji-ja", "utf-8", function(ok, err)
  if not ok then
    vim.notify("skk.nvim: SKK-JISYO.emoji-ja の読み込みに失敗しました: " .. tostring(err), vim.log.levels.WARN)
  end
end)

-- 【推測ベース・実機要検証】skkeleton.lua にあった Normal モードでの <C-j>
-- （"i<Plug>(skkeleton-enable)" = 挿入モードに入りつつ即座に有効化）の代替。
-- skk.nvim の setup() は挿入モード・コマンドラインモードにしか enter_key を
-- マップしないため、Normal モード分だけここで自作する。startinsert の後、
-- <C-j> を feedkeys で再注入し、setup() が登録した挿入モードの <C-j> マッピング
-- （ひらがなモードへの遷移）に処理を委ねる。skk.nvim 本体が正式に提供する
-- 仕組みではないため、実機での動作確認が必要。
vim.keymap.set("n", "<C-j>", function()
  vim.cmd("startinsert")
  vim.schedule(function()
    local keys = vim.api.nvim_replace_termcodes("<C-j>", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end)
end, { desc = "skk.nvim: enter insert mode and hiragana mode" })
