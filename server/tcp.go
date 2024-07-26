package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"strconv"
	"strings"

	"github.com/neovim/go-client/msgpack"
)

type CursorCoordinates struct {
	row int
	col int
}

func (c CursorCoordinates) Update(row int, col int) {
	c.row = row
	c.col = col
}

func connectionTCP(port int) {
	// fmt.Println(fmt.Sprintf("%d:", port))
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to create tcp listener: %v", err)
	}
	defer listener.Close()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Failed to accept connection: %v", err)
			continue
		}

		go handleTCP(conn)
	}
}

func handleTCP(conn net.Conn) {
	reader := bufio.NewReader(conn)
	encoder := msgpack.NewEncoder(conn)
	decoder := msgpack.NewDecoder(conn)

	for {
		// decoder.Decode()
		// Read data from the connection.
		buffer, err := reader.ReadString('\n')
		if err != nil {
			fmt.Println("Error reading:", err.Error())
			return
		}

		data := strings.Split(string(buffer), ",")
		fmt.Println(data)

		row, err := strconv.Atoi(data[1])
		if err != nil {
			fmt.Println("Error reading:", err.Error())
			return
		}

		col, err := strconv.Atoi(data[2])
		if err != nil {
			fmt.Println("Error reading:", err.Error())
			return
		}

		players[data[0]].coordinates.Update(row, col)

		fmt.Print("Received data: ", string(buffer))

		// Do stuff with the data
		// For demonstration, let's just send it back to the client.
		_, err = conn.Write([]byte("Message received: " + buffer))
		if err != nil {
			fmt.Println("Error writing:", err.Error())
			return
		}
	}
}
