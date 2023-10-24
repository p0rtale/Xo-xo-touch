package main

import (
	"bufio"
	"encoding/json"
	"log"
	"net"
	"strconv"
	"time"
)
import "fmt"

type ResToken struct {
	Token string `json:"token"`
}

func catch(err error) {
	if err != nil {
		log.Println(err)
	}
}

const sleepConst = 100
const sleepBetweenConst = 2

func printRequest(conn net.Conn, reqType string) {
	res, err := bufio.NewReader(conn).ReadString('}')
	catch(err)
	fmt.Println("Request (" + reqType + "): " + res)
	time.Sleep(sleepConst * time.Millisecond)
}

func printBroadcast(conn2 net.Conn) {
	res2, err := bufio.NewReader(conn2).ReadString('}')
	catch(err)
	fmt.Println("\nBroadcast: " + res2 + "\n")
	//time.Sleep(sleepConst * time.Millisecond)
}

func registerAndEntergame(conn net.Conn, conn2 net.Conn, usernames []string) []string {
	tokens := []string{}
	for _, u := range usernames {
		// Register
		fmt.Fprintf(conn, "{\"method\": \"register\", \"username\": \""+u+"\", \"password\": \"parol123\"}\n")
		res, err := bufio.NewReader(conn).ReadString('}')
		catch(err)
		fmt.Println("Request (register): ...")
		time.Sleep(sleepConst * time.Millisecond)
		resToken := ResToken{}
		err = json.Unmarshal([]byte(res), &resToken)
		catch(err)
		token := resToken.Token
		tokens = append(tokens, token)

		// Entergame
		fmt.Fprintf(conn, "{\"method\": \"entergame\", \"token\": \""+token+"\"}\n")
		printRequest(conn, "entergame")

		go printBroadcast(conn2)
	}
	return tokens
}

func saveAnswers(conn net.Conn, conn2 net.Conn, tokens []string) {
	for qn := range []int{0, 1} {
		for i, t := range tokens {
			// Get question
			fmt.Fprintf(conn, "{\"method\": \"getquestion\", \"token\": \""+t+"\"}\n")
			printRequest(conn, "getquestion")

			// Save answer
			fmt.Fprintf(conn, "{\"method\": \"saveanswer\", \"token\": \""+t+"\", \"answer\": \"ans "+strconv.Itoa(qn)+"."+strconv.Itoa(i)+"!\"}\n")
			printRequest(conn, "saveanswer")

			go printBroadcast(conn2)
		}
	}
}

func sendVotes(conn net.Conn, conn2 net.Conn, tokens []string) {
	for i := range tokens {
		fmt.Println("----- Voting:", i)
		for _, t := range tokens {
			// Get duel
			fmt.Fprintf(conn, "{\"method\": \"getduel\", \"token\": \""+t+"\"}\n")
			printRequest(conn, "getduel")

			// Save vote
			fmt.Fprintf(conn, "{\"method\": \"savevote\", \"vote\": 1, \"token\": \""+t+"\"}\n")
			printRequest(conn, "savevote")
		}

		go printBroadcast(conn2)
		fmt.Fprint(conn, "{\"method\": \"getduelresult\", \"token\": \""+tokens[0]+"\"}\n")
		printRequest(conn, "getduelresult")
		time.Sleep(sleepBetweenConst * time.Second)
	}
}

func main() {
	// Подключаемся к сокету
	fmt.Println("Start client")
	conn, err := net.Dial("tcp", "127.0.0.1:8081")
	catch(err)
	conn2, err := net.Dial("tcp", "127.0.0.1:8082")
	catch(err)

	tokens := registerAndEntergame(conn, conn2, []string{"dovolniy", "Yuriy", "Andrew", "user4", "user5"})
	time.Sleep(3 * time.Second)

	saveAnswers(conn, conn2, tokens)

	sendVotes(conn, conn2, tokens)

	printBroadcast(conn2)

}
