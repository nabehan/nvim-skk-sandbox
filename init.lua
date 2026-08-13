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

			skk.setup({
				skkserv = { host = "127.0.0.1", port = 1178, encoding = "euc-jp" },
				user_dictionary = vim.fn.expand("~/.local/share/skk/SKK-JISYO.user"),
				egg_like_newline = true,
				blink = { max_items = 50 },
			})

			-- 動作確認用の最小辞書。実機の辞書ファイルがあればそちらに差し替えてよい。
			dict.set_dict(require("skk.dict.jisyo_parser").parse(table.concat({
				";; okuri-nasi entries.",
				"かんじ /漢字/幹事/",
				"かんたん /簡単/",
				"とうきょう /東京/",
			}, "\n")))
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
							return require("skk.henkan.state").get_phase() == "midashi"
						end,
					},
				},
			},
		},
		opts_extend = { "sources.default" },
	},
})

-- ===================================================================
-- ▽/▼ 表示に合わせて blink.cmp のメニューを show()/hide() する
-- （実機の nvim-config-blink-skkeleton の blink.lua と同じロジック）
-- ===================================================================
vim.api.nvim_create_autocmd("User", {
	pattern = "SkkHenkanChanged",
	callback = function(ev)
		local blink = require("blink.cmp")
		local phase = ev.data and ev.data.phase

		if phase == "select" then
			vim.g.my_skk_cmp_suppressed = true
			blink.hide()
		elseif phase == "midashi" then
			vim.g.my_skk_cmp_suppressed = false
			vim.schedule(function()
				blink.show()
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
