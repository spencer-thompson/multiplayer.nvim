# Start with a minimal base image
# FROM alpine:latest
FROM archlinux:latest

# RUN apt-get -y update && apt-get -y install lua5.4 websocketd

# Install Lua and websocketd
# RUN apk add --no-cache lua websocketd
# RUN apk update && apk add --no-cache lua lua-socket websocketd

RUN pacman -Syu neovim

COPY . .

# Set the default command to run websocketd
# CMD ["websocketd", "--port=8080", "lua", "your_script.lua"]
