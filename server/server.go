package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"github.com/golang-jwt/jwt"
	"github.com/google/uuid"
	"io"
	"log"
	"math/rand"
	"net"
	"time"
)

const (
	StatusOk             = 200
	ErrAlreadyRegistered = 409
	ErrInvalidData       = 401
	ErrAlreadyLoggedIn   = 403
)

type User struct {
	Username string `json:"username"`
	Password string `json:"password"`
	UserId   string
}

type Session struct {
	UserId     string
	ConnReq    net.Conn
	ConnBrcast net.Conn
	GameId     int64
}

type Duel struct {
	Username1   string `json:"username1"`
	Username2   string `json:"username2"`
	QuestionNum int64  `json:"questionnum"`
}

type Game struct {
	GameId        int64
	Sessions      map[string]*Session
	IsGameStarted bool
	RoundNum      int64
	Duels         []*Duel
}

type Memory struct {
	//Mutex    *sync.Mutex
	Users      map[string]*User
	Games      map[int64]*Game
	lastGameId int64
	Sessions   map[string]*Session
}

type ResponseToken struct {
	Status int64  `json:"status"`
	Token  string `json:"token"`
}

type ResponseUsername struct {
	Status   int64  `json:"status"`
	Username string `json:"username"`
}

type ResponseNewPlayer struct {
	Type     string `json:"type"`
	Username string `json:"username"`
}

type ResponseGamePlayers struct {
	Status    int64    `json:"type"`
	Usernames []string `json:"usernames"`
}

type ResponseGameStarted struct {
	Type      string   `json:"type"`
	Usernames []string `json:"usernames"`
}

type UserJWT struct {
	Username string `json:"username"`
	UserID   string `json:"id"`
}

type UserJWTClaims struct {
	User UserJWT `json:"user"`
	jwt.StandardClaims
}

var tokenSecret = []byte("super secret")

func createJWT(userId string, username string) string {
	token := jwt.NewWithClaims(
		jwt.SigningMethodHS256,
		UserJWTClaims{
			User: UserJWT{
				UserID:   userId,
				Username: username,
			},
		},
	)
	tokenString, err := token.SignedString(tokenSecret)
	if err != nil {
		log.Println(err)
	}
	return tokenString
}

func (mem *Memory) registerHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	//mem.Mutex.Lock()
	//defer mem.Mutex.Unlock()

	// Get data
	u := User{}
	err := json.Unmarshal([]byte(data), &u)
	if err != nil {
		log.Println(err)
	}

	// Check if user is already registered
	for _, v := range mem.Users {
		if u.Username == v.Username {
			fmt.Println("ERROR This username is already registered")
			sendErr, err := json.Marshal(&ResponseToken{Status: ErrAlreadyRegistered})
			if err != nil {
				log.Println(err)
			}
			_, err = connReq.Write(sendErr)
			if err != nil {
				log.Println(err)
			}
			return
		}
	}

	// Create user
	u.UserId = uuid.New().String()
	mem.Users[u.UserId] = &u

	// Create session
	mem.Sessions[u.UserId] = &Session{
		ConnReq:    connReq,
		ConnBrcast: connBrcast,
		UserId:     u.UserId,
		GameId:     -1,
	}

	// Create and send JWT token
	token := createJWT(u.UserId, u.Username)
	sendData, err := json.Marshal(&ResponseToken{Status: StatusOk, Token: token})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}

	fmt.Printf("{\"method\": \"entergame\", \"token\": \"%s\"}\n\n", token)
}

func (mem *Memory) loginHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	// Get data
	u := User{}
	err := json.Unmarshal([]byte(data), &u)
	if err != nil {
		log.Println(err)
	}

	// Check user exists
	userFound := false
	for _, v := range mem.Users {
		if u.Username == v.Username && u.Password == v.Password {
			userFound = true
			break
		}
	}
	if !userFound {
		fmt.Println("ERROR This username is not found")
		sendData, err := json.Marshal(&ResponseToken{Status: ErrInvalidData})
		if err != nil {
			log.Println(err)
		}
		_, err = connReq.Write(sendData)
		if err != nil {
			log.Println(err)
		}
		return
	}

	// Check user is not logged in
	for _, v := range mem.Users {
		if u.Username == v.Username && mem.Sessions[v.UserId] != nil {
			fmt.Println("ERROR This username is already logged in")
			sendData, err := json.Marshal(&ResponseToken{Status: ErrAlreadyLoggedIn})
			if err != nil {
				log.Println(err)
			}
			_, err = connReq.Write(sendData)
			if err != nil {
				log.Println(err)
			}
			return
		}
	}

	// Create session
	userId := ""
	for _, v := range mem.Users {
		if u.Username == v.Username {
			userId = v.UserId
		}
	}
	mem.Sessions[u.UserId] = &Session{
		ConnReq:    connReq,
		ConnBrcast: connBrcast,
		UserId:     userId,
		GameId:     -1,
	}

	// Create and send JWT token
	token := createJWT(u.UserId, u.Username)
	sendData, err := json.Marshal(&ResponseToken{Status: StatusOk, Token: token})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
}

func (mem *Memory) checkToken(tokenString string) (*Session, error) {
	hashSecretGetter := func(token *jwt.Token) (interface{}, error) {
		method, ok := token.Method.(*jwt.SigningMethodHMAC)
		if !ok || method.Alg() != "HS256" {
			return nil, fmt.Errorf("bad sign method")
		}
		return tokenSecret, nil
	}
	token, err := jwt.ParseWithClaims(tokenString, &UserJWTClaims{}, hashSecretGetter)
	if err != nil || !token.Valid {
		return nil, fmt.Errorf("jwt validation error")
	}

	payload, ok := token.Claims.(*UserJWTClaims)
	if !ok {
		return nil, fmt.Errorf("no payload")
	}

	userID := payload.User.UserID

	return mem.Sessions[userID], nil
}

func (mem *Memory) getSessionAndToken(connReq net.Conn, data string) (*Session, error) {
	// Get data
	pToken := &struct{ Token string }{Token: ""}
	err := json.Unmarshal([]byte(data), &pToken)
	if err != nil {
		log.Println(err)
	}
	// Check token and get session
	session, err := mem.checkToken(pToken.Token)
	if err != nil {
		fmt.Println("ERROR JWT token failed")
		sendData, err := json.Marshal(&ResponseToken{Status: ErrInvalidData})
		if err != nil {
			log.Println(err)
		}
		_, err = connReq.Write(sendData)
		if err != nil {
			log.Println(err)
		}
		return nil, fmt.Errorf("JWT token failed")
	}
	return session, nil
}

func (mem *Memory) getUsername(connReq net.Conn, data string) {
	session, err := mem.getSessionAndToken(connReq, data)
	if err != nil {
		log.Println(err)
	}
	sendData, err := json.Marshal(&ResponseUsername{Status: StatusOk, Username: mem.Users[session.UserId].Username})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
}

func (mem *Memory) enterGameHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.getSessionAndToken(connReq, data)

	// If connection was lost (на ввсякий случай)
	session.ConnReq = connReq
	session.ConnBrcast = connBrcast

	usersCnt := len(mem.Games[mem.lastGameId].Sessions)
	// [0 в комнате] Предыдущая комната начала игру -> Создать новую игру
	if usersCnt == 3 {
		mem.lastGameId = mem.lastGameId + 1
		mem.Games[mem.lastGameId] = &Game{
			GameId:        mem.lastGameId,
			IsGameStarted: false,
		}
	}
	lastGame := mem.Games[mem.lastGameId]

	// [0-2 в комнате]
	// Разослать всем имя нового игрока
	var usernamesIn []string
	for _, s := range lastGame.Sessions {
		username := mem.Users[session.UserId].Username
		sendData, err := json.Marshal(&ResponseNewPlayer{Type: "newplayer", Username: username})
		if err != nil {
			log.Println(err)
		}
		sendData = append(sendData, []byte("\n")...)
		_, err = s.ConnBrcast.Write(sendData)
		if err != nil {
			log.Println(err)
		}
		usernamesIn = append(usernamesIn, mem.Users[s.UserId].Username)
	}
	// Отослать новому игроку список тех, кто уже в комнате
	sendData, err := json.Marshal(&ResponseGamePlayers{Status: StatusOk, Usernames: usernamesIn})
	if err != nil {
		log.Println(err)
	}
	sendData = append(sendData, []byte("\n")...)
	_, err = session.ConnReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
	// Сохранить сессию нового игрока в эту игру
	lastGame.Sessions[session.UserId] = session

	// [2 в комнате] Начать игру
	if usersCnt == 2 {
		lastGame.IsGameStarted = true
		go mem.delayedStartGame(lastGame)
	}
}

var questions = [10]string{
	"В плохом офисе вид из окна на _____",
	"Без чего не обходится деревенская свадьба?",
	"Взятка?! Разве считается взяткой то, что я просто дал судье _____?",
	"О чем мечтает робот-пылесос, пока заряжыется?",
	"Название планеты, полностью покрытой кукурузой",
	"Удивительная вещь, которую можно найти застрявшей в паутине в вашем подвале",
	"Даже за 10 миллионов рублей ты не наколешь эту фразу у себя на спине",
	"Водителям на зметку: Не стоит управлять машиной и _____ одновременно",
	"Твоя квартира рельно большая, если у тебя есть комната специально для _____",
	"В будущем Америка переименуется в _____",
}

func (mem *Memory) delayedStartGame(lastGame *Game) {
	time.Sleep(3 * time.Second)
	// Broadcast
	var usernames []string
	for _, u := range lastGame.Sessions {
		usernames = append(usernames, mem.Users[u.UserId].Username)
	}
	for _, s := range lastGame.Sessions {
		sendData, err := json.Marshal(&ResponseGameStarted{Type: "gamestarted", Usernames: usernames})
		if err != nil {
			log.Println(err)
		}
		sendData = append(sendData, []byte("\n")...)
		_, err = s.ConnBrcast.Write(sendData)
		if err != nil {
			log.Println(err)
		}
	}

	// Создание пар (дуэлей)
	var keys []string
	for k := range mem.Sessions {
		keys = append(keys, k)
	}
	rand.Shuffle(len(keys), func(i, j int) { keys[i], keys[j] = keys[j], keys[i] })
	q := int64(0)
	for i := range keys {
		duel := &Duel{
			Username1:   mem.Users[keys[i]].Username,
			Username2:   mem.Users[keys[(i+1)%len(keys)]].Username,
			QuestionNum: q,
		}
		q += 1
		lastGame.Duels = append(lastGame.Duels, duel)
	}
}

func (mem *Memory) getDuelsHandler(connReq net.Conn, data string) {
	_, err := mem.getSessionAndToken(connReq, data)
	if err != nil {
		fmt.Println(err)
	}

	lastGame := mem.Games[mem.lastGameId]
	fmt.Println(lastGame.Duels)
	sendData, err := json.Marshal(&lastGame.Duels)
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
}

func (mem *Memory) newClient(connReq net.Conn, connBrcast net.Conn) {
	for {
		data, err := bufio.NewReader(connReq).ReadString('\n')
		if err == io.EOF { // Соединение разорвано = Достигнут конец файла
			fmt.Println("Closed request connection:", connReq.RemoteAddr().String())
			// Удалить сессию, если соединение разорвано
			for _, s := range mem.Sessions {
				if s.ConnReq == connReq {
					delete(mem.Sessions, s.UserId)
				}
			}
			return
		}
		fmt.Println("Message Received:", data)
		req := &struct{ Method string }{Method: ""}
		err = json.Unmarshal([]byte(data), &req)
		if err != nil {
			log.Println(err)
		}

		switch req.Method {
		case "register":
			go mem.registerHandler(connReq, connBrcast, data)
		case "login":
			go mem.loginHandler(connReq, connBrcast, data)
		case "getusername":
			go mem.getUsername(connReq, data)
		case "entergame":
			go mem.enterGameHandler(connReq, connBrcast, data)
		case "getduels":
			go mem.getDuelsHandler(connReq, data)
		}
	}
}

func main() {
	fmt.Println("Start")

	// Listen port
	lnReq, err := net.Listen("tcp", ":8081")
	if err != nil {
		log.Println(err)
	}
	lnBrcast, err := net.Listen("tcp", ":8082")
	if err != nil {
		log.Println(err)
	}

	mem := &Memory{
		//Mutex:    &sync.Mutex{},
		Users:      map[string]*User{},
		Sessions:   map[string]*Session{},
		lastGameId: 0,
		Games:      map[int64]*Game{},
	}
	mem.Games[0] = &Game{
		GameId:        0,
		Sessions:      make(map[string]*Session),
		IsGameStarted: false,
	}

	for {
		//Accept port
		connReq, err := lnReq.Accept()
		if err != nil {
			log.Println(err)
			continue
		}
		fmt.Println("Got request connection from:", connReq.RemoteAddr().String())

		connBrcast, err := lnBrcast.Accept()
		if err != nil {
			log.Println(err)
			continue
		}
		fmt.Println("Got broadcast connection from:", connBrcast.RemoteAddr().String())

		go mem.newClient(connReq, connBrcast)
	}
}

//var wg sync.WaitGroup
//wg.Add(1)
// ...
//wg.Wait()

//d := &Data{
//	Origin: payload.Origin,
//	User:   payload.User,
//	Active: payload.Active,
//}
