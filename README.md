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
      opts = {
        -- show the tool group instead of individual tools in the chat buffer
        collapse_tools = true,
        tool_opts = {
          source = {
            -- load the file content from the
            -- filesystem when possible.
            prefer_filesystem = true,
          }
        }
        -- interval between 2 DAP action.
        -- set this to a larger value if you're hitting rate limits
        -- from your LLM provider.
        interval_ms = 1000, 
      }
    }
  }
}
```

# Usage

After you've started a DAP session, you can use the tool group `@{dap}` in a chat 
buffer to supply the tools from this extension to the LLM.

Currently the following DAP requests are implemented:

* **`breakpoints`**: Get, set, and clear breakpoints in the current DAP
  session.
* **`evaluate`**: Evaluate an expression or variable within the context of a
  stack frame.
* **`scopes`**: Get the available scopes for a specified stack frame.
* **`source`**: Fetch the content of a source file by its reference or file path.
* **`stackTrace`**: Obtain the call stack (stack trace) for a given thread.
* **`stepping`**: Execute stepping actions (`stepIn`, `stepOut`, `stepBack`, `next`,
  `continue`) in the debug session.
* **`stepInTargets`**: Get all possible step-in targets for the current source
  location.
* **`threads`**: Retrieve a list of all active threads in the current DAP session.
* **`variables`**: Inspect variables within a specific scope or variable reference.

More features are on the way.
