return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(bufnr)
        if vim.bo[bufnr].filetype == "ipynb" then
          return false
        end
      end,
    },
  },
  {
    "GCBallesteros/NotebookNavigator.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-mini/mini.comment", "benlubas/molten-nvim" },
    opts = { repl_provider = "molten" },
  },
  {
    "goerz/jupytext.nvim",
    version = "0.2.0",
    opts = { format = "py:percent", autosync = true },
  },
}
