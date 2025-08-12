> [!WARNING]
> This plugin is currently under active development. Expect breaking changes and many bugs

# Multiplayer

... video game like cooperative editing inside Neovim.

## Install


- Lazy:

```lua
{
  "spencer-thompson/multiplayer.nvim",
  build = 'cd comms; cargo build --release',
  opts = {}
},
```

- vim-plug:

```vim
Plug 'spencer-thompson/multiplayer.nvim', { 'do': 'cd comms && cargo build --release' }
lua require("multiplayer").setup({})
```

### Dependencies

`cargo`

## Usage

### Coop

Shared buffers for the joining client only exist in memory.
Saving a buffer that is shared will synchronize the buffer with the host.

`:Coop host`

`:Coop join`

## Configuration

The plugin is built to work fine out of the box, although the available config options are below:

```lua
{
  username = "my_username", -- default is git username
  uppercase_marks = true,   -- use uppercase (global) marks
}
```


## Overview

As an overall glance of how I want this project to go, essentially, I want to use Neovim buffers (which is just text held in memory) and use the Neovim API to track buffer updates. I have already implemented this successfully (twice) using the `nvim_buf_attach()` api function inside of Neovim. I want to track cursor positions and use something like marks to be able to jump to another collaborators position within the file or project. As a side note this `nvim_buf_attach()` function is how Neovim is able to provide lsp support and effectively track every single change in a buffer.

Currently, I see this project broken into three major chunks.

- **The Algorithm**: For realtime editing (managing indices, inserts, deletes, undos)
- **The Networking**: For communication between clients (and server?)
- **The Architecture**: Edge cases + the structure of the application and how that relates to editing a file / a project and managing sessions.

Regarding The editing algorithm, I have done quite a bit of research regarding different methods that are already being used to create applications like this (ex: google docs, zed editor). The real three main options I have found are:

