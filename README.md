> [!WARNING]
> This plugin is currently under active development. Expect breaking changes and many bugs

# Multiplayer

... video game like cooperative editing inside Neovim.

## Install

- Lazy:

```lua
{
  "spencer-thompson/multiplayer.nvim",
  opts = {}
},
```

## Overview

As an overall glance of how I want this project to go, essentially, I want to use Neovim buffers (which is just text held in memory) and use the Neovim API to track buffer updates. I have already implemented this successfully (twice) using the `nvim_buf_attach()` api function inside of Neovim. I want to track cursor positions and use something like marks to be able to jump to another collaborators position within the file or project. As a side note this `nvim_buf_attach()` function is how Neovim is able to provide lsp support and effectively track every single change in a buffer.

Currently, I see this project broken into three major chunks.

- **The Algorithm**: For realtime editing (managing indices, inserts, deletes, undos)
- **The Networking**: For communication between clients (and server?)
- **The Architecture**: Edge cases + the structure of the application and how that relates to editing a file / a project and managing sessions.

Regarding The editing algorithm, I have done quite a bit of research regarding different methods that are already being used to create applications like this (ex: google docs, zed editor). The real three main options I have found are:

- [Operational Transformation](https://en.wikipedia.org/wiki/Operational_transformation): Which essentially utilizes a central server that manages insertions and deletions to make sure that clients converge to a source of truth. This method is relatively simple with the concept of `f(insert_1, insert_2): ... if insert_1 and insert_2 have indices that would conflict then resolve them`
    - Pros:
        - No metadata overhead
        - Relatively straightforward algorithm
        - More mature algorithm
    - Cons:
        - Central Server needed to manage edits
- [CRDTs](https://www.youtube.com/watch?v=x7drE24geUw): These are unique new class of algorithms that essentially take text (in a buffer or file) and convert that text into a new data structure. The idea being that if every character, for example, has its own unique index that has an ordering, text edits can have the commutative property. This is interesting because it allows for edits to be applied in any order (theoretically) and still converge to the same document. (Note: the video I linked is very interesting explaining the different types of CRDTs)
    - Pros:
        - Its pretty cool
        - Decentralized, no central server needed
    - Cons:
        - Metadata overhead (can 5x-10x file sizes)
        - More complex to implement
- Simple Heuristics: If all else we can always use something like last writer wins. This is much simpler, but we would lose a lot of nuances.
    - Pros:
        - Simple
    - Cons:
        - Merges can be overwritten
        - Writes are complicated.

For networking I have explored a lot of different options, and frankly I think that the methodology doesn't matter so much, but I think I want to use the least amount of external dependencies possible just to aim for easy maintainability in the future. I have spent quite a bit of time pouring over the neovim documentation to figure out what kind of functionality is built in.

- **Websockets**: Simple bidirectional communication between clients or client and server.
    - Pros:
        - Simple
        - Widely utilized
    - Cons:
        - Extensive to implement, or requires a dependency
- **[QUIC](https://blog.cloudflare.com/the-road-to-quic/)**: A newer option that uses UDP to provide robust and low latency communication that can be multiplexed easily.
    - Pros:
        - Very interesting and promising new option
        - Secure by default
        - Supports multiple connections at once
    - Cons:
        - Complicated and new (minimal documentation)
- **TCP**: There is builtin TCP and UDP into the Neovim API.
    - Pros:
        - Bulitin support inside neovim.
        - Simple
    - Cons:
        - Not as exciting
        - Complex implementation


Lastly, regarding architecture I want to design this so that an entire project can be worked on with realtime collaboration.
This raises issues like when another user edits a different buffer in the same project.

Additionally, there are many edge cases and complications, but I am excited and motivated.

I think if I needed to use something other than Lua (Which is embedded into Neovim), I would want to use Rust.

Some ideas and possible solutions:

- LAN Party: I would like this tool to be similar to the old-school LAN parties, this has the benefit of eliminating the need for a separate server, at least during development.
- If we need to use more tools, I think I would like to use QUIC with Rust simply because it sounds exciting.
- I think using git to our advantage, for example enforcing either starting with the same empty buffer, or the same commit hash within a repo.
