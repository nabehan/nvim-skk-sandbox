-- ~/.config/nvim-skk-sandbox/init.lua
-- skk.nvim の blink.cmp ネイティブソース統合を、日常使いの設定
-- （config.nvim_lazy_blink）に触れずに検証するための最小構成。
-- 起動: NVIM_APPNAME=nvim-skk-sandbox nvim（エイリアス例は README 参照）
--
-- 【要編集】local SKK_NVIM_DEV_DIR のパスを、実機の skk.nvim
-- 開発ディレクトリ（skk_test_init.lua がある場所）に置き換えてください。
local SKK_NVIM_DEV_DIR = vim.fn.expand("~/Project/skk.nvim") -- ★ここを実際のパスに変更

local vim = vim

vim.keymap.set("", "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.termguicolors = true

-- ===================================================================
-- lazy.nvim 自動インストール
-- ===================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ===================================================================
-- プラグイン
-- ===================================================================
require("lazy").setup({
  -- skk.nvim: ローカルの開発ディレクトリを直接参照する（dir指定）。
  -- GitHubにpushしなくても、編集がそのまま次回起動時に反映される。
  -- GitHub版（nabehan/skk.nvim）で試したい場合は、この spec を
  -- { "nabehan/skk.nvim" } に差し替える。
  {
    "skk.nvim",
    dir = SKK_NVIM_DEV_DIR,
    lazy = false,
    config = function()
      local skk = require("skk")
      local dict = require("skk.dict")
      local parser = require("skk.dict.jisyo_parser")

      -- setup() に渡す skkserv 設定。通知ブロック側でも参照するため
      -- 先に変数として持っておく（skk.setup はセットアップ「関数」であり
      -- オプションテーブルではないので、skk.setup.skkserv のような参照は
      -- 「関数を index しようとしてエラー」になる）。
      -- local skkserv_opts = { host = "127.0.0.1", port = 1178, encoding = "euc-jp", debug = true } -- ★暫定：debug=true は速度調査用。原因特定後に削除
      local skkserv_opts = { host = "127.0.0.1", port = 1178, encoding = "euc-jp" }
      -- ローカル辞書。空にすると、下の組み込みの小さな確認用辞書が使われる
      -- （dictionaries が空のときに setup() へ渡さないのはこのサンドボックス
      -- だけの便宜機能。skk.nvim 本体の setup() には無い）。
      local dictionaries = {
        { path = "/usr/local/share/skk/SKK-JISYO.jawiki", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.edict2", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.emoji", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.emoji-ja", encoding = "utf-8" },
      }

      -- 辞書の読み込み完了数をカウントする変数 for develop
      local loaded_count = 0

      -- skkserv の疎通確認を行う関数 for develop
      local function check_skkserv()
        if not skkserv_opts then
          return
        end
        local version = dict.skkserv_version()
        if version then
          vim.notify("skk.nvim: skkserv version: " .. version)
        else
          local detail = dict.skkserv_last_connect_error()
          vim.notify(
            "skk.nvim: skkserv に接続できませんでした ("
              .. skkserv_opts.host
              .. ":"
              .. skkserv_opts.port
              .. ")。status="
              .. dict.skkserv_status()
              .. (detail and (" error=" .. tostring(detail)) or "")
              .. "。ホスト/ポート、サーバーの起動状態を確認してください。",
            vim.log.levels.WARN
          )
        end
      end

      skk.setup({
        skkserv = skkserv_opts,
        user_dictionary = vim.fn.expand("~/.local/share/skk/SKK-JISYO.user"),
        enter_key = "<C-j>",
        sticky_shift_enabled = true,
        sticky_shift_key = ";",
        egg_like_newline = true,
        candidate_window = {
          border = "rounded",
          -- "rounded"/"single"/"double"/"none"/自前の文字配列。省略時 "rounded"
          annotation = true,
          -- 候補一覧に辞書の注釈（;注釈）を表示するか。省略時 true
          page_indicator = true,
          -- false にすると最下行のページ表示（"2/3"など）を出さない
          threshold = 2,
          -- 省略時のデフォルト。1にすると、これまで通り最初の<SPC>で即ウィンドウ表示
        },
        -- blink = { max_items = 5, skip_skkserv = false, debug_timing = true }, -- ★暫定：max_items=5 は速度調査用。原因特定後に50へ戻す
        blink = {
          max_items = 50,
          -- 前方一致で取得する読みの上限件数。省略時50
          skip_skkserv = false,
          -- "4"（読み一覧取得）にSKKサーバーを含めるか。省略時false（含める）
          skkserv_candidates = true,
          -- "1"（実際の変換候補=漢字の取得）にSKKサーバーを含めるか。
          -- falseにすると個人辞書・ローカル辞書の候補のみになる。省略時true
          skkserv_candidate_limit = 20,
          -- SKKサーバーへ実際に"1"を投げる読みの上限件数（skkserv_candidates=true
          -- のときのみ意味を持つ）。増やすほど、ライブ補完メニューの下の方まで
          -- 漢字候補が出るようになる代わりに、その分だけキー入力ごとの直列
          -- ラウンドトリップが増えて体感が重くなりうる。逆に減らす（0にすると
          -- 実質skkserv_candidates=falseと同じ）ほど軽くなるが、上限を超えた
          -- 読みは「読みのみ」のフォールバック項目になる（<SPC>で▼へ進めば
          -- 従来通り変換候補は見られる）。体感を比較したいときはこの値と、
          -- 下のdebug_timing=trueを併用するとよい（キー入力ごとに
          -- [skk.nvim timing] ... skkserv_calls=N ... のログが出る）。
          debug_timing = true,
        },
        dictionaries = #dictionaries > 0 and dictionaries or nil,
        on_dictionary_loaded = function(path, ok, err)
          vim.schedule(function()
            if ok then
              vim.notify("skk.nvim: dictionary loaded: " .. path)
            else
              vim.notify("skk.nvim: failed to load " .. path .. ": " .. tostring(err), vim.log.levels.WARN)
            end
            -- 辞書のカウントを進める
            loaded_count = loaded_count + 1
            -- すべてのローカル辞書の読み込みが終わったら skkserv の疎通確認を実行する
            if loaded_count >= #dictionaries then
              check_skkserv()
            end
          end)
        end,
      })

      if #dictionaries == 0 then
        -- ローカル辞書が指定されていない場合は直ちに疎通確認を実行する
        check_skkserv()
        -- 動作確認用の小さな組み込み辞書（送りなし・送りあり両方のサンプルを含む）
        local mini_jisyo = table.concat({
          ";; okuri-ari entries.",
          "うごk /動/",
          "あかk /赤/",
          ";; okuri-nasi entries.",
          "かんじ /漢字/幹事/監事/",
          "うごく /動く/",
          "あい /愛/",
          "にほん /日本/",
        }, "\n")
        dict.set_dict(parser.parse(mini_jisyo))
        vim.schedule(function()
          vim.notify("skk.nvim: using built-in mini dictionary (init.lua の dictionaries を編集してください)")
        end)
      end
    end,
  },

  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        list = { selection = { preselect = true, auto_insert = false } },
        menu = {
          draw = {
            columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
          },
        },
      },
      sources = {
        default = { "skk", "lsp", "path", "snippets", "buffer" },
        providers = {
          skk = {
            name = "[SKK]",
            module = "skk.blink_source",
            min_keyword_length = 0,
            score_offset = 100,
            enabled = function()
              -- "midashi"（▽、通常のかな漢字変換）だけでなく "abbrev"
              -- （▽、"/" で始める英字そのままの見出し）でも有効にする
              -- （実機で発見：abbrev だけライブ補完が出ない不具合があった）。
              local phase = require("skk.henkan.state").get_phase()
              return phase == "midashi" or phase == "abbrev"
            end,
          },
        },
      },
    },
    opts_extend = { "sources.default" },
  },
})

-- ===================================================================
-- ▽/▼ 表示に合わせて blink.cmp のメニューを show()/hide() する。
-- 【注意】実機の nvim-config-blink-skkeleton の blink.lua 側は、
-- この providers 指定の修正がまだ反映されていない（今後の移行作業で
-- 反映する）。
-- ===================================================================
vim.api.nvim_create_autocmd("User", {
  pattern = "SkkHenkanChanged",
  callback = function(ev)
    local blink = require("blink.cmp")
    local phase = ev.data and ev.data.phase

    if phase == "select" then
      vim.g.my_skk_cmp_suppressed = true
      blink.hide()
    elseif phase == "midashi" or phase == "abbrev" then
      vim.g.my_skk_cmp_suppressed = false
      vim.schedule(function()
        -- 読みが1文字変わるたびに、この elseif 節が毎回呼ばれる。
        -- blink.cmp の show() は「メニューが既に開いていて providers を
        -- 指定しない場合は何もしない」というガードがあるため、何も考えずに
        -- blink.show() を呼ぶだけだと、▽に入った直後（読みがまだ空文字）の
        -- 1回目でメニューが開いた後、2文字目以降の呼び出しはすべて無視されて
        -- しまう（= 候補リストが更新されない）。
        --
        -- skk.nvim の ▽/▼ は extmark（仮想テキスト）表示で実バッファは
        -- 一切変化しないため、blink.cmp 自身の「実テキストの変更を検知して
        -- 自動的に再要求する」通常の仕組みも働かない。
        --
        -- そのため providers = { "skk" } を明示して呼ぶ。cmp.show() は
        -- opts.providers が指定されている場合はこのガードをすり抜けて
        -- 必ず再トリガーする実装になっている（blink.cmp 本体
        -- lua/blink/cmp/init.lua の show() 参照）。
        blink.show({ providers = { "skk" } })
      end)
    else
      vim.g.my_skk_cmp_suppressed = false
      blink.hide()
    end
  end,
})

vim.opt.number = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
