package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"github.com/golang-jwt/jwt"
	"github.com/google/uuid"
	"io"
	"log"
	"net"
	"time"
)

const maxUsersCntConst = 5
const sleepBetweenConst = 2

const (
	StatusOk           = 200
	ErrAlreadyd        = 409
	ErrInvalidData     = 401
	ErrAlreadyLoggedIn = 403
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
	Question  string             `json:"question"`
	Usernames []string           `json:"usernames"`
	Answers   []string           `json:"answers"`
	Votes     map[int64][]string `json:"votes"` // posInDuel -> array of username voted
}

type Game struct {
	GameId        int64
	Sessions      map[string]*Session // userId -> session
	IsGameStarted bool
	Duels         []*Duel
	QuestionNum   map[string]int64 // userId -> questionNum
	IsVoted       map[string]bool  // userId -> isVoted
	DuelNum       int64
	MaxUsersCnt   int64
	RoundNum      int64
}

type Memory struct {
	//Mutex    *sync.Mutex
	Users      map[string]*User // userId -> user
	Games      map[int64]*Game  // gameId -> game
	lastGameId int64
	Sessions   map[string]*Session // userIs -> sessison
}

type RequestMethod struct {
	Method string `json:"method"`
}

type RequestToken struct {
	Token string `json:"token"`
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
	Message  string `json:"message"`
	Username string `json:"username"`
}

type ResponseGamePlayers struct {
	Status    int64    `json:"status"`
	Usernames []string `json:"usernames"`
}

type ResponseBrcastMessage struct {
	Message string `json:"message"`
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

func (mem *Memory) registerHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	//mem.Mutex.Lock()
	//defer mem.Mutex.Unlock()

	// Get data
	u := User{}
	err := json.Unmarshal([]byte(data), &u)
	if err != nil {
		log.Println(err)
	}

	// Check if user is already d
	for _, v := range mem.Users {
		if u.Username == v.Username {
			fmt.Println("ERROR This username is already d")
			sendErr, err := json.Marshal(&ResponseToken{Status: ErrAlreadyd})
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
	token := createToken(u.UserId, u.Username)
	sendData, err := json.Marshal(&ResponseToken{Status: StatusOk, Token: token})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}

	//fmt.Printf("{\"method\": \"entergame\", \"token\": \"%s\"}\n\n", token)
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
	token := createToken(u.UserId, u.Username)
	sendData, err := json.Marshal(&ResponseToken{Status: StatusOk, Token: token})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
}

func createToken(userId string, username string) string {
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

func (mem *Memory) checkToken(connReq net.Conn, connBrcast net.Conn, data string) (*Session, error) {
	// Get data
	pToken := RequestToken{}
	err := json.Unmarshal([]byte(data), &pToken)
	if err != nil {
		log.Println(err)
	}
	tokenString := pToken.Token

	// Check
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

	userId := payload.User.UserID

	// Если пришел токен, но нет такого юзера (не зарегистрирован или не вошел)
	if mem.Users[userId] == nil {
		fmt.Println("ERROR JWT token failed: This user is not logged in")
		sendData, err := json.Marshal(&ResponseToken{Status: ErrInvalidData})
		if err != nil {
			log.Println(err)
		}
		_, err = connReq.Write(sendData)
		if err != nil {
			log.Println(err)
		}
		return nil, fmt.Errorf("ERROR JWT token failed: This user is not logged in")
	}

	// Если соединение потеряно, но есть верный токен, то создать новую сессию
	if mem.Sessions[userId] == nil {
		mem.Sessions[userId] = &Session{
			ConnReq:    connReq,
			ConnBrcast: connBrcast,
			UserId:     userId,
			GameId:     -1,
		}
	}

	return mem.Sessions[userId], nil
}

func (mem *Memory) getUsernameHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		log.Println(err)
		return
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
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		log.Println(err)
		return
	}

	if mem.Games[0] == nil {
		mem.Games[0] = &Game{
			GameId:        0,
			Sessions:      map[string]*Session{},
			IsGameStarted: false,
			QuestionNum:   map[string]int64{},
			IsVoted:       map[string]bool{},
			DuelNum:       0,
			MaxUsersCnt:   maxUsersCntConst,
			RoundNum:      0,
		}
	}

	// Для нулевой игры. Для новых игр выполняется то же действие.
	if mem.lastGameId == 0 {
		session.GameId = mem.lastGameId
	}

	// If connection was lost (на всякий случай)
	session.ConnReq = connReq
	session.ConnBrcast = connBrcast

	lastGame := mem.Games[mem.lastGameId]
	usersCnt := int64(len(lastGame.Sessions))
	maxUsersCnt := mem.Games[session.GameId].MaxUsersCnt
	// [0 в комнате] Предыдущая комната начала игру -> Создать новую игру
	if usersCnt == maxUsersCnt {
		mem.lastGameId += 1
		session.GameId = mem.lastGameId
		mem.Games[mem.lastGameId] = &Game{
			GameId:        mem.lastGameId,
			IsGameStarted: false,
			QuestionNum:   map[string]int64{},
			IsVoted:       map[string]bool{},
			DuelNum:       0,
			MaxUsersCnt:   maxUsersCntConst,
			RoundNum:      0,
		}
	}

	// [0-2 из 3 в комнате]
	// Разослать всем имя нового игрока
	usernamesIn := []string{}
	for _, s := range lastGame.Sessions {
		username := mem.Users[session.UserId].Username
		sendData, err := json.Marshal(&ResponseNewPlayer{Message: "newplayer", Username: username})
		if err != nil {
			log.Println(err)
		}
		//sendData = append(sendData, []byte("\n")...)
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
	//sendData = append(sendData, []byte("\n")...)
	_, err = session.ConnReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
	// Сохранить сессию нового игрока в эту игру
	lastGame.Sessions[session.UserId] = session
	// Заполнить номер дуэли в раунде
	lastGame.QuestionNum[session.UserId] = 0

	// [2 из 3 в комнате] Начать игру
	if usersCnt == maxUsersCnt-1 {
		lastGame.IsGameStarted = true
		go mem.delayedStartGame(lastGame, session)
	}
}

var questions = []string{
	"question1?",
	"question2?",
	"question3?",
	"question4?",
	"question5?",
	"В плохом офисе вид из окна на _____",
	"Без чего не обходится деревенская свадьба?",
	"О чем мечтает робот-пылесос, пока заряжыется?",
	"Взятка?! Разве считается взяткой то, что я просто дал судье _____?",
	"Название планеты, полностью покрытой кукурузой",
	"Удивительная вещь, которую можно найти застрявшей в паутине в вашем подвале",
	"Даже за 10 миллионов рублей ты не наколешь эту фразу у себя на спине",
	"Водителям на зметку: Не стоит управлять машиной и _____ одновременно",
	"Твоя квартира рельно большая, если у тебя есть комната специально для _____",
	"В будущем Америка переименуется в _____",
}

func (mem *Memory) sendBroadcastMessage(session *Session, message string) {
	sendData, err := json.Marshal(&ResponseBrcastMessage{Message: message})
	if err != nil {
		log.Println(err)
	}
	for _, s := range mem.Games[session.GameId].Sessions {
		_, err = s.ConnBrcast.Write(sendData)
		if err != nil {
			log.Println(err)
		}
	}
}

func (mem *Memory) delayedStartGame(lastGame *Game, session *Session) {
	time.Sleep(3 * time.Second)
	// Broadcast
	mem.sendBroadcastMessage(session, "gamestarted")

	// Создание пар (дуэлей)
	userIds := []string{}
	for u := range lastGame.Sessions {
		userIds = append(userIds, u)
	}
	//rand.Shuffle(len(userIds), func(i, j int) { userIds[i], userIds[j] = userIds[j], userIds[i] })
	q := int64(0)
	for i := range userIds {
		username1 := mem.Users[userIds[i]].Username
		username2 := mem.Users[userIds[(i+1)%len(userIds)]].Username
		duel := &Duel{
			Question:  questions[q],
			Usernames: []string{username1, username2},
			Answers:   make([]string, 2),
			Votes:     map[int64][]string{},
		}
		q += 1
		lastGame.Duels = append(lastGame.Duels, duel)
	}
}

func getDuelsByUsername(username string, game *Game) []*Duel {
	userDuels := []*Duel{}
	for _, duel := range game.Duels {
		for _, usernameInDuel := range duel.Usernames {
			if usernameInDuel == username {
				userDuels = append(userDuels, duel)
			}
		}
	}
	return userDuels
}

func (mem *Memory) getQuestionHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		fmt.Println(err)
	}

	game := mem.Games[session.GameId]
	duels := getDuelsByUsername(mem.Users[session.UserId].Username, game)
	sendData, err := json.Marshal(&struct {
		Status   int64  `json:"status"`
		Question string `json:"question"`
	}{
		Status:   StatusOk,
		Question: duels[game.QuestionNum[session.UserId]].Question,
	})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
}

func getPosInDuelByUsername(username string, duel *Duel) int64 {
	for i, u := range duel.Usernames {
		if u == username {
			return int64(i)
		}
	}
	return -1
}

func sendStatus(connReq net.Conn, status int64) {
	sendData, err := json.Marshal(&struct {
		Status int64 `json:"status"`
	}{
		Status: status,
	})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}
}

func (mem *Memory) saveAnswerHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		fmt.Println(err)
	}

	answer := struct {
		Answer string `json:"answer"`
	}{
		Answer: "",
	}
	err = json.Unmarshal([]byte(data), &answer)
	if err != nil {
		log.Println(err)
	}

	game := mem.Games[session.GameId]
	username := mem.Users[session.UserId].Username
	duels := getDuelsByUsername(username, game)
	questionNum := game.QuestionNum[session.UserId]

	if questionNum == 2 {
		sendStatus(connReq, ErrInvalidData)
	}

	//fmt.Println("questionNum =", questionNum)
	posInDuel := getPosInDuelByUsername(mem.Users[session.UserId].Username, duels[questionNum])
	fmt.Println("USERNAME =", duels[questionNum].Usernames[posInDuel])
	duels[questionNum].Answers[posInDuel] = answer.Answer
	fmt.Println("QUESTION:", duels[questionNum].Question)
	fmt.Println("ANSWER:", answer.Answer)
	fmt.Println()
	//if questionNum == 1 {
	//	fmt.Println()
	//	for _, d := range game.Duels {
	//		fmt.Println("DUELS:", d)
	//	}
	//}

	// Ответ клиенту
	lastAnswer := false
	if questionNum == 1 {
		lastAnswer = true
	}
	sendData, err := json.Marshal(&struct {
		Status     int64 `json:"status"`
		LastAnswer bool  `json:"lastanswer"`
	}{
		Status:     StatusOk,
		LastAnswer: lastAnswer,
	})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}

	mem.Games[session.GameId].QuestionNum[session.UserId] += 1 // questionNum = ...

	// Броадкаст о том, что все ответили
	everyoneAnswered := true
	for _, sess := range mem.Games[session.GameId].Sessions {
		gameIn := mem.Games[sess.GameId]
		if gameIn.QuestionNum[sess.UserId] != 2 {
			everyoneAnswered = false
		}
	}
	if everyoneAnswered {
		mem.sendBroadcastMessage(session, "everyoneanswered")
		fmt.Println("-------------------------------------------------------")
	}
}

func (mem *Memory) getDuelHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		fmt.Println(err)
	}

	game := mem.Games[session.GameId]
	// Нельзя голосовать после конца голосования
	if game.DuelNum == game.MaxUsersCnt {
		sendStatus(connReq, ErrInvalidData)
		return
	}
	duel := game.Duels[game.DuelNum]

	sendData, err := json.Marshal(&struct {
		Status   int64    `json:"status"`
		Question string   `json:"question"`
		Answers  []string `json:"answers"`
		DuelNum  int64    `json:"duelnum"`
	}{
		Status:   StatusOk,
		Question: duel.Question,
		Answers:  duel.Answers,
		DuelNum:  game.DuelNum,
	})
	if err != nil {
		log.Println(err)
	}
	_, err = connReq.Write(sendData)
	if err != nil {
		log.Println(err)
	}

	//fmt.Println()
	//for _, d := range mem.Games[session.GameId].Duels {
	//	fmt.Println("DUELS:", d)
	//}
	//fmt.Println()
}

func (mem *Memory) saveVoteHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		fmt.Println(err)
	}

	game := mem.Games[session.GameId]
	// Нельзя голосовать после конца голосования
	if game.DuelNum == game.MaxUsersCnt {
		sendStatus(connReq, ErrInvalidData)
		return
	}
	duel := game.Duels[game.DuelNum]
	username := mem.Users[session.UserId].Username

	// Нельзя голосовать за вопрос, на который ты отвечал
	if duel.Usernames[0] == username || duel.Usernames[1] == username {
		sendStatus(connReq, ErrInvalidData)
		return
	}

	res := &struct {
		Vote int64 `json:"vote"`
	}{
		Vote: -1,
	}
	err = json.Unmarshal([]byte(data), res)
	if err != nil {
		log.Println(err)
	}
	fmt.Println("USERNAME =", mem.Users[session.UserId].Username)
	fmt.Println("DUELNUM =", game.DuelNum)
	fmt.Println("VOTE =", res.Vote)
	fmt.Println()

	// Добавляем в список проголосовавших за человека имя проголосовавшего
	mem.Games[session.GameId].Duels[game.DuelNum].Votes[res.Vote] = append(mem.Games[session.GameId].Duels[game.DuelNum].Votes[res.Vote], mem.Users[session.UserId].Username)
	mem.Games[session.GameId].IsVoted[session.UserId] = true

	// Ответ клиенту
	sendStatus(connReq, StatusOk)

	// Если все проголосовали за дуэль, то выбираем следующую дуэль. + Броадкаст
	duelVotingEnded := true
	for _, sess := range game.Sessions {
		gameIn := mem.Games[sess.GameId]
		usernameIn := mem.Users[sess.UserId].Username
		if duel.Usernames[0] == usernameIn || duel.Usernames[1] == usernameIn {
			continue
		}
		//fmt.Println(duel.Usernames[0], "VS", duel.Usernames[1], "VOTER =", usernameIn)
		userVoted := gameIn.IsVoted[sess.UserId]
		if !userVoted {
			duelVotingEnded = false
		}
		//fmt.Println("ISVOTED", gameIn.IsVoted[sess.UserId])
		//fmt.Println()
	}
	if duelVotingEnded {
		//fmt.Println("!!! duelVotingEnded")
		//fmt.Println()
		for _, sess := range game.Sessions {
			userVoted := game.IsVoted[sess.UserId]
			if userVoted {
				game.IsVoted[sess.UserId] = false
			}
		}

		// Броадкаст о том, что все ответили на все вопросы
		roundVotingEnded := true
		//fmt.Println(game.DuelNum, "VS", game.MaxUsersCnt)
		if game.DuelNum+1 != game.MaxUsersCnt {
			roundVotingEnded = false
		}
		if roundVotingEnded {
			mem.sendBroadcastMessage(session, "roundvotingended")
			go mem.broadcastNewRoundStarted(session) // go, чтоб клиент мог топ раунда

			for _, d := range game.Duels {
				fmt.Println("DUELS:", d)
			}
			fmt.Println()
		} else {
			mem.sendBroadcastMessage(session, "duelvotingended")
			go mem.broadcastNewDuelVotingStarted(session) // go, чтоб клиент мог показать рез. дуэти
		}
	}
}

func (mem *Memory) broadcastNewDuelVotingStarted(session *Session) {
	time.Sleep(sleepBetweenConst * time.Second)
	mem.sendBroadcastMessage(session, "newduelvotingstarted")
	mem.Games[session.GameId].DuelNum += 1
}

func (mem *Memory) broadcastNewRoundStarted(session *Session) {
	time.Sleep(sleepBetweenConst * time.Second)
	mem.sendBroadcastMessage(session, "newroundstarted")
	mem.Games[session.GameId].RoundNum += 1
}

func (mem *Memory) getDuelResultsHandler(connReq net.Conn, connBrcast net.Conn, data string) {
	session, err := mem.checkToken(connReq, connBrcast, data)
	if err != nil {
		fmt.Println(err)
	}

	game := mem.Games[session.GameId]
	// Нельзя запрашивать результаты, если время на это истекло
	if game.DuelNum == game.MaxUsersCnt {
		sendStatus(connReq, ErrInvalidData)
		return
	}
	duel := game.Duels[game.DuelNum]

	sendData, err := json.Marshal(&struct {
		Status    int64    `json:"status"`
		Question  string   `json:"question"`
		Usernames []string `json:"usernames"`
		Answers   []string `json:"answers"`
	}{
		Status:    StatusOk,
		Question:  duel.Question,
		Usernames: duel.Usernames,
		Answers:   duel.Answers,
	})
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
		//fmt.Println("Message Received:", data)
		req := RequestMethod{}
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
			go mem.getUsernameHandler(connReq, connBrcast, data)
		case "entergame":
			go mem.enterGameHandler(connReq, connBrcast, data)
		case "getquestion":
			go mem.getQuestionHandler(connReq, connBrcast, data)
		case "saveanswer":
			go mem.saveAnswerHandler(connReq, connBrcast, data)
		case "getduel":
			go mem.getDuelHandler(connReq, connBrcast, data)
		case "savevote":
			go mem.saveVoteHandler(connReq, connBrcast, data)
		case "getduelresult":
			go mem.getDuelResultsHandler(connReq, connBrcast, data)
			//case "getroundresult":
			//	go mem.getRoundResultsHandler(connReq, connBrcast, data)
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
		fmt.Println()

		go mem.newClient(connReq, connBrcast)
	}
}

//var wg sync.WaitGroup
//wg.Add(1)
// ...
//wg.Wait()
