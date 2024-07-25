package main

import (
	// "bufio"
	"fmt"
	"log"
	"net"

	"github.com/neovim/go-client/msgpack/rpc"
	// "github.com/neovim/go-client/nvim"
)

// Example method to be called from Neovim
func Hello(args ...interface{}) (string, error) {
	return "Hello from Go!", nil
}

func something(args ...interface{}) error {
	fmt.Println(args...)
	return nil
}

// func something(v *nvim.Nvim, args []string) error {
// 	return v.Notify("Hello world", nvim.LogInfoLevel, nil)
// }

// func test()

// func bufatttach(v *nvim.Nvim, args []string) error {
// return v.AttachBuffer(, sendBuffer bool, opts map[string]interface{})
// }

func main() {
	listener, err := net.Listen("tcp", ":5111")
	if err != nil {
		log.Fatalf("Failed to create listener: %v", err)
	}
	defer listener.Close()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Failed to accept connection: %v", err)
			continue
		}
		// Create a new endpoint
		endpoint, err := rpc.NewEndpoint(conn, conn, conn)
		if err != nil {
			log.Printf("Failed to create endpoint: %v", err)
			conn.Close()
			continue
		}

		// Register methods
		err = endpoint.Register("something", something)
		if err != nil {
			log.Printf("Failed to register method: %v", err)
			conn.Close()
			continue
		}

		// Serve requests
		go func() {
			err := endpoint.Serve()
			// err := endpoint.Notify()
			if err != nil {
				log.Printf("Serve error: %v", err)
			}
		}()
		// go handleConnection(conn)
	}
}

// func handleConnection(conn net.Conn) {
// 	defer conn.Close()
//
// 	fmt.Println("New connection accepted")
//
// 	scanner := bufio.NewScanner(conn)
// 	for scanner.Scan() {
// 		// Print whatever is received
// 		fmt.Println("Received:", scanner.Text())
// 	}
//
// 	if err := scanner.Err(); err != nil {
// 		fmt.Println("Error reading from connection:", err)
// 	}
// }
