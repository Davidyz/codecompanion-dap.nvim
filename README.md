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
        interval_ms = 1000,
        winfixbuf = true,

        tool_opts = {
          evaluate = {
            requires_approval = true,
          },
          source = {
            -- load the file content from the
            -- filesystem when possible.
            prefer_filesystem = true,
          }
        }
      }
    }
  }
}
```

# Usage

## Before You Start...

Debugging (with DAP) is usually an interactive process. The developer sends some 
requests to the DAP server, the server take some actions and send some data
back. When we give this control to the LLM, it may end up (inevitably) send a lot 
of requests to keep the LLM updated about the current DAP session. This means, if 
you're using a provider with strict token per minute (TPM) or request per minute 
(RPM) restrictions, you might hit that limit faster than you usually do. The
`interval_ms` option helps, but it's probably not enough to solve this issue for
good.

## Tools

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

# Configuration

## Extension Options

- **`interval_ms`**: To mitigate this, you may use the `interval_ms` option to set 
  the minimum delay between DAP requests. This helps avoid hitting rate limits from 
  your LLM provider.
- **`winfixbuf`**: When set to true, the codecompanion window's `winfixbuf`
  option will be enabled. When this is enabled, the DAP stepping actions won't
  occupy the codecompanion chat buffer.

## Tool Options
All tools have the following config option available:
- `requires_approval`: `true` to require user approval before running this tool.
  Default: `true` for evaluate, `false` for others.

The `source` tool has an extra option:
- `prefer_filesystem`: `true` to load content from local file when possible, 
  `false` to always load it from the DAP server. Default: `true`.
