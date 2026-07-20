return {
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
