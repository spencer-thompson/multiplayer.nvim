package main

import (
	// "bufio"
	"fmt"
	// "log"
	// "net"
	// "strings"
	// "reflect"
	// "github.com/neovim/go-client/msgpack/rpc"
	// "github.com/neovim/go-client/nvim"
)

var players map[string]playerInfo

type playerInfo struct {
	username    string
	coordinates CursorCoordinates
}

func main() {
	players = make(map[string]playerInfo)

	go connectionTCP(5111)
	go connectionRCP(5112)

	fmt.Scanln()
}
