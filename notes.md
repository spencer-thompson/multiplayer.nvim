# Networking

I think there is a question of TCP vs QUIC (UDP).

I really want to use QUIC due to ultra low latency, but there is no built in support for QUIC.

If we use QUIC we would need to use a local domain socket / named pipe (windows).

# Edits

# Client / Server

I the plugin to be able to act as the server. This is an important feature.

I think the server portion of the code should be written in rust and handle most of the networking logic and handling of edits.

With the `mlua` rust crate we can expose rust functions to lua and vice versa.
