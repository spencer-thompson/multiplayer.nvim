FROM archlinux:latest

WORKDIR /app

RUN pacman -Syu neovim git --noconfirm --needed

COPY ./server/init.lua .
COPY ./lua/multiplayer.lua .

