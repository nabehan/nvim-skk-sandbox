-- ~/.config/nvim/lua/my/cmp/blink.lua
-- nvim-cmp -> blink.cmp 移行後のメイン設定
-- ===================================================================
local vim = vim
local blink = require("blink.cmp")
local luasnip = require("luasnip")

-- ===================================================================
-- LuaSnip
-- ===================================================================
luasnip.config.set_config({
  history = true,
  updateevents = "TextChanged,TextChangedI",
})

-- スニペット本体（today/now/dw 等）を登録する
require("my.cmp.LuaSnipCustom")

-- ===================================================================
-- 有効/無効トグル用フラグ（lua/my/cmp/keymap.lua の <C-q> から操作）
-- ===================================================================
vim.g.my_blink_enabled = true
vim.g.my_skk_cmp_suppressed = false -- ★追加: ▼(変換候補選択)中はtrueにしてblink.cmpを止める
-- ===================================================================
-- source ごとの表示名（メニューにブラケット付きで表示するためのラベル）
-- ※ providers.*.name は blink.compat がソース実体を解決するための
-- 「nvim-cmp 側の登録名」なので、表示専用の変換はここで別管理する
-- ===================================================================
local SOURCE_LABELS = {
  skk = "[SKK]",
  snippets = "[SNIP]",
  lsp = "[LSP]",
  path = "[PATH]",
  buffer = "[BUF]",
  calc = "[CALC]",
  emoji = "[EMOJI]",
  latex_symbols = "[LATEX]",
  spell = "[SPELL]",
  rg = "[rGREP]",
  regex = "[REGEX]",
  cmdline = "[CMD]",
}

-- ===================================================================
-- spell: 英字4文字以上のときだけ有効（旧 cmp-spell 設定を移植）
-- ===================================================================
local function spell_enable_in_context()
  local col = vim.fn.col(".") - 1
  if col <= 0 then
    return false
  end
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)
  local word = before:match("([A-Za-z]+)$")
  return word ~= nil and #word >= 4
end

-- ===================================================================
-- filetype ごとの source 一覧（common + 用途別追加）
-- ===================================================================
local common_providers = {
  "skk",
  "snippets",
  "lsp",
  "path",
  "calc",
  "emoji",
  "latex_symbols",
  "buffer",
  "spell",
}

local prog_filetypes = {
  "lua",
  "python",
  "c",
  "cpp",
  "rust",
  "go",
  "sh",
  "zsh",
  "bash",
  "javascript",
  "typescript",
  "typst",
  "latex",
}

local writing_filetypes = { "markdown", "text", "mdx" }

local function default_sources()
  local ft = vim.bo.filetype

  if vim.tbl_contains(prog_filetypes, ft) then
    -- プログラミング言語: rg + spell を追加
    local list = vim.deepcopy(common_providers)
    table.insert(list, "rg")
    -- table.insert(list, "spell")
    return list
  elseif vim.tbl_contains(writing_filetypes, ft) then
    -- 文章系: spell のみ追加（rg は重いので含めない）
    local list = vim.deepcopy(common_providers)
    table.remove(list, 8)
    -- table.insert(list, "spell")
    return list
  else
    return vim.deepcopy(common_providers)
  end
end

-- ===================================================================
-- グローバルセットアップ
-- ===================================================================
blink.setup({
  -- -------------------------------------------------------------
  -- 有効/無効（<C-q> でトグル）
  -- -------------------------------------------------------------
  enabled = function()
    -- return vim.g.my_blink_enabled and vim.bo.buftype ~= "prompt"
    return vim.g.my_blink_enabled and vim.bo.buftype ~= "prompt" and not vim.g.my_skk_cmp_suppressed
  end,

  -- -------------------------------------------------------------
  -- snippet エンジン
  -- -------------------------------------------------------------
  -- 【注意】組み込みの snippets = { preset = "luasnip" } は使わない。
  -- 未マージの LuaSnip PR に依存した実験的実装で、確定直後に
  -- LuaSnip のセッション追跡が壊れ E565 エラーが出る不具合が確認された。
  -- 代わりに lua/my/cmp/luasnip_source.lua（プレーンテキスト挿入のみ）+
  -- 独自の <Tab> キーマップ（安定版 API での expand_or_jump）を使う。

  -- -------------------------------------------------------------
  -- fuzzy matcher
  -- -------------------------------------------------------------
  fuzzy = { implementation = "prefer_rust_with_warning" },

  -- -------------------------------------------------------------
  -- appearance
  -- -------------------------------------------------------------
  appearance = {
    nerd_font_variant = "mono",
    use_nvim_cmp_as_default = true,
  },

  -- -------------------------------------------------------------
  -- キーマッピング（旧 nvim-cmp のマッピングを踏襲）
  -- -------------------------------------------------------------
  keymap = {
    preset = "none",

    ["<C-n>"] = { "select_next", "fallback" },
    ["<C-p>"] = { "select_prev", "fallback" },

    ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    ["<C-b>"] = { "scroll_documentation_up", "fallback" },

    ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },

    ["<C-e>"] = { "hide", "fallback" },

    -- <Tab> / <S-Tab>: LuaSnip のジャンプを優先し、なければ通常動作へ
    -- 【重要】成功時は必ず true を return すること。blink.cmp のキーマップは
    -- 関数が nil/false を返すと次のアクション（ここでは "fallback"）に
    -- 進んでしまう仕様のため、return を省略すると LuaSnip のジャンプが
    -- 成功した直後に余計な <Tab> がもう一度実行されてしまう。
    -- また、実際の nvim_buf_set_text は vim.schedule で1ティック遅らせる。
    -- blink.cmp のキーマップ実行コンテキストの中で直接バッファを書き換えると
    -- "E565: Not allowed to change text or change window" が発生するため。
    ["<Tab>"] = {
      function()
        if luasnip.expand_or_jumpable() then
          vim.schedule(function()
            luasnip.expand_or_jump()
            blink.hide() -- 日付の数字列に反応した calc 等のポップアップを閉じる
          end)
          return true
        end
      end,
      "fallback",
    },
    ["<S-Tab>"] = {
      function()
        if luasnip.jumpable(-1) then
          vim.schedule(function()
            luasnip.jump(-1)
            blink.hide()
          end)
          return true
        end
      end,
      "fallback",
    },

    -- LuaSnip choice_node の切り替え（スニペット内でのみ有効。dw スニペットなど）
    -- こちらも同様に、成功時は必ず true を return し、実際の変更は
    -- vim.schedule で遅延させる。
    ["<C-l>"] = {
      function()
        if luasnip.choice_active() then
          vim.schedule(function()
            luasnip.change_choice(1)
            blink.hide()
          end)
          return true
        end
      end,
      "fallback",
    },
    ["<C-h>"] = {
      function()
        if luasnip.choice_active() then
          vim.schedule(function()
            luasnip.change_choice(-1)
            blink.hide()
          end)
          return true
        end
      end,
      "fallback",
    },

    -- 確定は blink 本来の accept に一本化する（自前挿入はしない）
    ["<CR>"] = {
      "accept",
      function(cmp)
        return cmp.accept({ force = true })
      end,
      "fallback",
    },
  },

  -- -------------------------------------------------------------
  -- completion 表示・選択まわり
  -- -------------------------------------------------------------
  completion = {
    keyword = { range = "prefix" },

    accept = {
      -- 関数呼び出し確定時に括弧を自動挿入（autopairs の map_cr=false の代替）
      auto_brackets = { enabled = true },
    },

    list = {
      selection = {
        -- 先頭候補を自動でハイライトしておく（SKK の ▼ 一番手候補を
        -- そのまま <CR> で確定できるようにするため）
        preselect = true,
        -- true にすると未確定のままバッファに挿入されてしまうので false 固定
        auto_insert = false,
      },
    },

    menu = {
      border = "rounded",
      draw = {
        columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
        components = {
          source_name = {
            text = function(ctx)
              return SOURCE_LABELS[ctx.source_name] or ("[" .. ctx.source_name .. "]")
            end,
            highlight = "Comment",
          },
        },
      },
    },

    documentation = {
      auto_show = true,
      auto_show_delay_ms = 150,
      window = { border = "rounded" },
    },

    ghost_text = { enabled = false },
  },

  signature = { enabled = false },

  -- -------------------------------------------------------------
  -- sources
  -- -------------------------------------------------------------
  sources = {
    default = default_sources,

    providers = {
      -- ---------------------------------------------------------
      -- built-in（表示名だけ上書き）
      -- ---------------------------------------------------------
      lsp = { name = SOURCE_LABELS.lsp },

      path = {
        name = SOURCE_LABELS.path,
        opts = {
          trailing_slash = true,
          label_trailing_slash = true,
        },
      },

      buffer = {
        name = SOURCE_LABELS.buffer,
        min_keyword_length = 3,
      },

      snippets = {
        name = SOURCE_LABELS.snippets,
        module = "my.cmp.luasnip_source",
        score_offset = 10,
      },

      -- ---------------------------------------------------------
      -- skk: ネイティブソース（skk.nvim 本体の lua/skk/blink_source.lua）
      -- ---------------------------------------------------------
      skk = {
        name = SOURCE_LABELS.skk,
        module = "skk.blink_source",
        min_keyword_length = 0,
        score_offset = 100, -- SKK 変換中は他ソースより優先して表示
        enabled = function()
          return require("skk.henkan.state").get_phase() == "midashi"
        end,
      },

      -- ---------------------------------------------------------
      -- blink.compat 経由の nvim-cmp ソース（skk 以外）
      -- name は必ず nvim-cmp 側の登録名と一致させること（表示名は上の
      -- SOURCE_LABELS と draw.components.source_name.text で処理する）
      -- ---------------------------------------------------------
      calc = {
        name = "calc",
        module = "blink.compat.source",
      },

      emoji = {
        name = "emoji",
        module = "blink.compat.source",
      },

      latex_symbols = {
        name = "latex_symbols",
        module = "blink.compat.source",
      },

      spell = {
        name = "spell",
        module = "blink.compat.source",
        min_keyword_length = 4,
        enabled = function()
          return spell_enable_in_context()
        end,
        opts = {
          keep_all_entries = false,
          preselect_correct_word = true,
        },
      },

      rg = {
        name = "rg",
        module = "blink.compat.source",
        score_offset = -3,
        opts = {
          context_before = 3,
          context_after = 5,
          max_files = 8,
          additional_arguments = "--max-count=10",
        },
      },

      -- ---------------------------------------------------------
      -- cmdline 専用（regex はネイティブ実装、cmdline は built-in の上書き）
      -- ---------------------------------------------------------
      regex = {
        name = SOURCE_LABELS.regex,
        module = "my.cmp.regex_source",
      },

      cmdline = { name = SOURCE_LABELS.cmdline },
    },
  },

  -- -------------------------------------------------------------
  -- cmdline（: / ? での補完）
  -- -------------------------------------------------------------
  cmdline = {
    enabled = true,
    keymap = {
      -- "cmdline" プリセットに任せると <CR> が accept 系にバインドされておらず
      -- 素の <CR>（＝タイプ中の生テキストで実行）に落ちてしまうため、
      -- 必要なキーはすべて明示的に定義する
      -- ["<Tab>"] = { "show", "select_next", "fallback" },
      -- ["<S-Tab>"] = { "show", "select_prev", "fallback" },
      ["<C-n>"] = { "show", "select_next", "fallback" },
      ["<C-p>"] = { "show", "select_prev", "fallback" },
      -- accept は候補をコマンドラインに挿入するだけで実行はしない。
      -- accept_and_enter は挿入と同時に確定（実行）まで行う。
      ["<CR>"] = { "accept_and_enter", "fallback" },
      ["<C-e>"] = { "cancel", "fallback" },
      -- ["<C-y>"] = { "select_and_accept" },
      ["<TAB>"] = { "select_and_accept" },
    },
    completion = {
      menu = { auto_show = true },
      -- 候補は明示的に <C-n>/<C-p> で選ぶまでコマンドラインへ反映しない。
      -- 以前 preselect/auto_insert を true にしていたが、":w" と打っただけで
      -- 先頭候補（例: ":wq"）が勝手にコマンドラインへ入ってしまう不具合の
      -- 原因だった。
      list = { selection = { preselect = false, auto_insert = false } },
    },
    sources = function()
      local cmdtype = vim.fn.getcmdtype()
      if cmdtype == "/" or cmdtype == "?" then
        return { "buffer", "regex" }
      elseif cmdtype == ":" then
        return { "cmdline", "path", "buffer", "regex" }
      end
      return {}
    end,
  },
})

-- ===================================================================
-- skk.nvim の ▽/▼ 表示に合わせて、blink.cmp の補完メニューを
-- 手動で show()/hide() する。
-- 【重要】確定後に skk.nvim 側のキャンセル処理を呼ぶことはしない。
-- lua/skk/blink_source.lua の execute() が確定処理そのもの
-- （henkan/state.lua の M.confirm_external() への委譲）を担っているため、
-- ここで余計にキャンセルを挟むと直前に挿入された文字列ごと巻き戻ってしまう
-- （skkeleton統合時代の教訓と同じ理由）。
--
-- skkeleton版と違い、テキストを走査して "▽"/"▼" を探す必要はない。
-- skk.nvim は状態変化のたびに User autocmd "SkkHenkanChanged" を
-- data.phase（"idle"/"midashi"/"select"/"abbrev"）付きで発火するため、
-- それをそのまま見ればよい。
-- ===================================================================
vim.api.nvim_create_autocmd("User", {
  pattern = "SkkHenkanChanged",
  callback = function(ev)
    local phase = ev.data and ev.data.phase

    if phase == "select" then
      -- 変換候補選択(▼)中: blink.cmp を完全に止める。
      -- enabled() 側で弾かれるので、blink.cmp 自身の自動表示も抑制される。
      vim.g.my_skk_cmp_suppressed = true
      blink.hide()
    elseif phase == "midashi" then
      -- 見出し語入力(▽)中: 従来どおり
      vim.g.my_skk_cmp_suppressed = false
      vim.schedule(function()
        blink.show()
      end)
    else
      -- idle（direct モード）または abbrev。直前まで▼だった場合はここが
      -- 確定/キャンセル直後のイベント。この場で再表示はせず抑制だけ解除する。
      -- 実際の再開は次に打鍵したタイミングで blink.cmp 自身の自動表示
      -- ロジックに任せる。
      vim.g.my_skk_cmp_suppressed = false
      blink.hide()
    end
  end,
})
