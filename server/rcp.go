package main

import (
	// "bufio"
	"fmt"
	"log"
	"net"
	// "strings"
	// "reflect"

	"github.com/neovim/go-client/msgpack/rpc"
	// "github.com/neovim/go-client/nvim"
)

// func cursor(args ...interface{}) {
// 	fmt.Println(args...)
// 	// for _, arg := range args {
// 	// 	fmt.Printf("Value: %v, Type: %T\n", arg, arg)
// 	// }
// 	// coord := CursorCoordinates{row: args[0].(int), col: args[1].(int)}
// }

func something(args ...interface{}) (string, error) {
	fmt.Println(args...)
	return "hello from server", nil
}

func cursor(args ...interface{}) error {
	players[args[0].(string)].coordinates.Update(int(args[1].(int64)), int(args[2].(int64)))
	return nil
}

// notify call
func user(args ...interface{}) error {
	players[args[0].(string)] = playerInfo{
		username:    args[0].(string),
		coordinates: CursorCoordinates{row: 1, col: 0},
	}
	fmt.Printf("Username received: %v", players[args[0].(string)].username)
	return nil
}

// func something(v *nvim.Nvim, args []string) error {
// 	return v.Notify("Hello world", nvim.LogInfoLevel, nil)
// }

// func test()

// func bufatttach(v *nvim.Nvim, args []string) error {
// return v.AttachBuffer(, sendBuffer bool, opts map[string]interface{})
// }

func connectionRCP(port int) {
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to create rcp listener: %v", err)
	}
	defer listener.Close()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Failed to accept connection: %v", err)
			continue
		}

		go handleRCP(conn)
	}
}

func handleRCP(conn net.Conn) {
	// defer conn.Close()

	endpoint, err := rpc.NewEndpoint(conn, conn, conn)
	if err != nil {
		log.Printf("Failed to create endpoint: %v", err)
		conn.Close()
	}

	err = endpoint.Register("HandleRequest", handleRequest, endpoint)

	// Register methods
	err = endpoint.Register("something", something)
	if err != nil {
		log.Printf("Failed to register method: %v", err)
		conn.Close()
	}

	err = endpoint.Register("cursor", cursor)
	if err != nil {
		log.Printf("Failed to register method: %v", err)
		conn.Close()
	}

	err = endpoint.Register("user", user)
	if err != nil {
		log.Printf("Failed to register method: %v", err)
		conn.Close()
	}

	if err := endpoint.Serve(); err != nil {
		log.Printf("Serve error: %v", err)
	}
}

func handleRequest(e *rpc.Endpoint, args ...interface{}) error {
	if len(args) < 1 {
		return fmt.Errorf("no arguments provided")
	}

	message := args[0].(string)
	fmt.Println("Received message:", message)

	// err := e.Call("nvim_echo", "Hello from server")
	// if err != nil {
	// 	return fmt.Errorf("error sending notification: %v", err)
	// }

	return nil
}

func handleEndpoint(e *rpc.Endpoint) {
	err := e.Serve()
	if err != nil {
		log.Printf("Serve error: %v", err)
	}
}
