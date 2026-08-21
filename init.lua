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

      -- setup() に渡す skkserv 設定。
      local skkserv_opts = {
        host = "127.0.0.1",
        port = 1178,
        encoding = "euc-jp",
        debug = false, -- true にすると送受信の生データを vim.notify() で出す（速度調査用）
        -- check_connection は既定 false（起動時の自動疎通確認はしない）。
        -- 手動で確認したいときは :SkkCheckSkkserv を使う。
      }
      -- ローカル辞書。空にすると、下の組み込みの小さな確認用辞書が使われる
      -- （dictionaries が空のときに setup() へ渡さないのはこのサンドボックス
      -- だけの便宜機能。skk.nvim 本体の setup() には無い）。
      local dictionaries = {
        -- { path = "/usr/local/share/skk/SKK-JISYO.LL.utf8", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.jawiki", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.edict2", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.emoji", encoding = "utf-8" },
        { path = "/usr/local/share/skk/SKK-JISYO.emoji-ja", encoding = "utf-8" },
      }

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
          --
          -- 配色（すべて省略時はカラースキームのNormalFloat/FloatBorderのまま、
          -- 現状と同じ見た目）。試したい場合はコメントを外す:
          -- fg = "#d8dee9", bg = "#2e3440",       -- 非選択の候補行
          border_fg = "#88c0d0", -- 枠線
          alt_bg = "#1b4252", -- 1行おきの縞模様（可読性向上、省略時は縞なし）
        },

        -- ▽/▼のインライン表示の配色（省略時はComment/IncSearchのまま、現状と同じ）。
        -- candidate_fg/bgは候補ウィンドウの選択行のハイライトにも連動する。
        midashi_fg = "#ff9e64", -- "#81a1c1",
        -- candidate_fg = "#000000", -- "#4c566a",
        -- candidate_bg = "#ebcb8b",

        -- 【実機で発見・重要】<C-n>/<C-p> による候補選択フォーカス移動は、
        -- skk.nvim 本体の candidate_navigation（setup()時に既存マッピングを
        -- 1回だけ捕捉してグローバルな <C-n>/<C-p> を張る仕組み）では
        -- このsandboxの構成（blink.cmpのキーマップがバッファローカル・
        -- 遅延適用のため）だと機能しない（blink.cmp側が後から張る
        -- バッファローカルなマッピングに必ず上書きされてしまう）。
        -- 代わりに下の blink.cmp 側の keymap 設定（<C-n>/<C-p> の
        -- カスタム関数コマンド）で対応しているため、ここでは無効化して
        -- 混乱を避ける。
        candidate_navigation = { enabled = false },

        blink = {
          max_items = 30,
          -- 前方一致で取得する読みの上限件数。省略時50
          skip_skkserv = false,
          -- "4"（読み一覧取得）にSKKサーバーを含めるか。省略時false（含める）
          skkserv_candidates = true,
          -- "1"（実際の変換候補=漢字の取得）にSKKサーバーを含めるか。
          -- falseにすると個人辞書・ローカル辞書の候補のみになる。省略時true
          skkserv_candidate_limit = 30,
          -- SKKサーバーへ実際に"1"を投げる読みの上限件数（skkserv_candidates=true
          -- のときのみ意味を持つ）。増やすほど、ライブ補完メニューの下の方まで
          -- 漢字候補が出るようになる代わりに、その分だけキー入力ごとの直列
          -- ラウンドトリップが増えて体感が重くなりうる。逆に減らす（0にすると
          -- 実質skkserv_candidates=falseと同じ）ほど軽くなるが、上限を超えた
          -- 読みは「読みのみ」のフォールバック項目になる（<SPC>で▼へ進めば
          -- 従来通り変換候補は見られる）。体感を比較したいときはこの値と、
          -- 下のdebug_timing=trueを併用するとよい（キー入力ごとに
          -- [skk.nvim timing] ... skkserv_calls=N ... のログが出る）。
          --
          -- 【実機で発見・重要】abbrevモード（</>で入る、ASCII文字列を
          -- そのまま前方一致検索するモード）は、かな読みでのライブ補完より
          -- 体感が遅くなりやすい。原因は往復回数そのものというより、辞書
          -- 側の変則エントリ（プログラム候補構文が読みに紛れ込んだもの、
          -- 例: jawiki辞書の"a(concat ...)"）にabbrevモードが当たりやすく、
          -- yaskkserv2のgoogle-japanese-inputフォールバック（既定
          -- notfound）がタイムアウトするまで詰まるため（skk.nvim側は
          -- "(" ")" '"' "\\" を含む読みへは"1"を送らない防御を追加済みだが、
          -- 未知のパターンが今後見つかる可能性はある）。詳細は
          -- skk.nvimのREADME.md「SKKサーバーとの通信の信頼性」の6番目の
          -- 項目参照。根本的に気になる場合はyaskkserv2.conf側で
          -- google-japanese-input = disable も検討できる。
          debug_timing = false,
        },

        dictionaries = #dictionaries > 0 and dictionaries or nil,
        -- 読み込み結果（成功/失敗・時刻）は :SkkDictionaries で後から
        -- いつでも確認できるので、on_dictionary_loaded での都度通知は
        -- 使っていない。
      })

      if #dictionaries == 0 then
        -- ローカル辞書が指定されていない場合の動作確認用の小さな組み込み辞書
        -- （送りなし・送りあり両方のサンプルを含む）。skkservの疎通確認は
        -- 手動なら :SkkCheckSkkserv、自動にしたければ skkserv.check_connection
        -- を true にする（lua/skk/init.lua の SkkSetupOpts の docstring参照）。
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
      keymap = {
        preset = "default",

        -- ===============================================================
        -- 【実機で発見・重要】<C-n>/<C-p> と skk.nvim の候補選択の競合。
        --
        -- blink.cmp の <C-n>/<C-p>（preset="default" では
        -- {"select_next"/"select_prev", "fallback_to_mappings"}）は
        -- バッファローカルかつ遅延適用（ModeChanged 契機）で張られるため、
        -- skk.nvim 側から一方的にグローバルキーマップで奪おうとしても
        -- 後から blink.cmp 側に上書きされてしまい効かない
        -- （skk.setup() の candidate_navigation はこの sandbox では
        -- 明示的に無効化してある。上のskk.setup()呼び出し参照）。
        --
        -- さらに "fallback_to_mappings" は「他の“本物の”キーマップが
        -- 無ければ何もせずキーを飲み込む」動作のため、skk.nvim が
        -- vim.on_key() しか使っていない状態では、blink.cmp 側の
        -- is_enabled()（sources.providers.skk.enabled 相当ではなく
        -- 全体の enabled）による抑制が正しく効いていたとしても、
        -- 候補一覧ウィンドウ表示中（▼/"select"フェーズ）に <C-n>/<C-p> が
        -- 完全に無効化されてしまう不具合があった。
        --
        -- 対策として、blink.cmp 自身がサポートするキーマップの
        -- カスタム関数コマンドを使う。henkan が ▼(select) フェーズなら
        -- skk.nvim 側の候補選択を実行して true を返し（そこでチェーンを
        -- 打ち切る）、そうでなければ false を返して従来通り
        -- "select_next"/"select_prev" → "fallback_to_mappings" の
        -- チェーンに委ねる（preset="default" と同じ動作を維持）。
        -- この方式なら読み込み順序やバッファローカルの優先順位を
        -- 一切気にする必要がない。
        --
        -- 【実機で発見・重要】通常バッファで E565（textlock）エラーが発生した。
        -- blink.cmp のキーマップコールバック実行中（＝Neovimがキー入力処理の
        -- 最中でtextlockが有効な状態）に focus_next()/focus_prev() を直接
        -- 呼ぶと、その先の candidate_window.show() が行う
        -- nvim_open_win()/nvim_buf_set_lines() がtextlockに阻まれてエラーに
        -- なる（コマンドラインで問題が出なかったのは、そちらはskk.nvim本体の
        -- vim.on_key() 経由で、このtextlockされた文脈を通らないため）。
        -- vim.schedule() でイベントループの次ティックに逃がすことで解消する。
        -- ===============================================================
        ["<C-n>"] = {
          function()
            if require("skk.henkan.state").get_phase() == "select" then
              vim.schedule(function()
                require("skk.henkan.state").focus_next()
              end)
              return true
            end
            return false
          end,
          "select_next",
          "fallback_to_mappings",
        },
        ["<C-p>"] = {
          function()
            if require("skk.henkan.state").get_phase() == "select" then
              vim.schedule(function()
                require("skk.henkan.state").focus_prev()
              end)
              return true
            end
            return false
          end,
          "select_prev",
          "fallback_to_mappings",
        },
      },
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
