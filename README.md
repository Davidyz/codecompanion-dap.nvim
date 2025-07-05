> A neovim plugin (and codecompanion extension) that bridges 
> [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim).

This codecompanion extension provides tools for the LLM to explore a currently
running DAP session.

This is an experimental attempt to using LLMs for debugging. I'm not power user
of nvim-dap, and I personally only use this with Python debuggers (debugpy and
coredumpy). Feel free to suggest new features/ideas that could make this more
powerful.

# Installation

Using `lazy.nvim`:
```lua
{
  "olimorris/codecompanion.nvim",
  dependencies = {
    {
      "Davidyz/codecompanion-dap.nvim",
      dependencies = {
        "mfussenegger/nvim-dap",
      },
    }
  },
  opts = {
    extensions = {
      dap = {
        enabled = true
      }
    }
  }
}
```

# Usage

After you've started a DAP session, you can use the tool group `@{dap}` in a chat 
buffer to supply the tools from this extension to the LLM.

Currently the following DAP requests are implemented:

*   **`threads`**: Retrieve a list of all active threads in the current DAP session.
*   **`source`**: Fetch the content of a source file by its reference or file path.
*   **`scopes`**: Get the available scopes for a specified stack frame.
*   **`stackTrace`**: Obtain the call stack (stack trace) for a given thread.
*   **`variables`**: Inspect variables within a specific scope or variable reference.

More features are on the way.
