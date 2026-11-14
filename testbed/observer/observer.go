// Raw request-line upstream observer for the testbed (local only, SCOPE.md).
//
// WireMock's Jetty rejects an ambiguous ".." request target at the HTTP parser
// (400 Bad Message) BEFORE it journals the request, so an escaping dot-segment
// path forwarded by a gateway is never recorded (review 8). This observer reads
// the raw request line off the socket itself — no URL parsing, no dot-segment
// resolution — and records the request target VERBATIM, so a decoded ".."
// upstream path is journaled exactly as sent. It also records whether the request
// carried the operator dummy key (Authorization), which is the second half of the
// INV-G6 frozen signature.
//
// Endpoints:
//   GET    /__journal  -> JSON array of recorded requests {method,target,op_key,auth}
//   DELETE /__journal  -> clear the journal
//   (anything else)    -> record it, return 200 {"ok":true,"observer":true}
//
// Stdlib only; run with `go run` in the pinned golang image (GOTOOLCHAIN=local,
// no modules, no network). Never a verdict/sanity build — a test observer.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"strconv"
	"strings"
	"sync"
)

type entry struct {
	Method string `json:"method"`
	Target string `json:"target"` // raw request target, verbatim (dot-segments intact)
	OpKey  bool   `json:"op_key"` // Authorization carried the operator dummy key
	Auth   string `json:"auth"`
}

var (
	mu      sync.Mutex
	journal []entry
)

const opKeyMarker = "operator-dummy-key"

func handle(conn net.Conn) {
	defer conn.Close()
	br := bufio.NewReader(conn)
	line, err := br.ReadString('\n')
	if err != nil {
		return
	}
	line = strings.TrimRight(line, "\r\n")
	parts := strings.SplitN(line, " ", 3)
	method, target := "", ""
	if len(parts) >= 2 {
		method, target = parts[0], parts[1]
	}
	auth := ""
	cl := 0
	for {
		h, err := br.ReadString('\n')
		if err != nil {
			break
		}
		h = strings.TrimRight(h, "\r\n")
		if h == "" {
			break
		}
		if i := strings.Index(h, ":"); i > 0 {
			k := strings.ToLower(strings.TrimSpace(h[:i]))
			v := strings.TrimSpace(h[i+1:])
			if k == "authorization" {
				auth = v
			} else if k == "content-length" {
				cl, _ = strconv.Atoi(v)
			}
		}
	}
	if cl > 0 {
		io.CopyN(io.Discard, br, int64(cl))
	}

	switch {
	case method == "GET" && strings.HasPrefix(target, "/__journal"):
		mu.Lock()
		b, _ := json.Marshal(journal)
		mu.Unlock()
		fmt.Fprintf(conn, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s", len(b), b)
		return
	case method == "DELETE" && strings.HasPrefix(target, "/__journal"):
		mu.Lock()
		journal = nil
		mu.Unlock()
		fmt.Fprint(conn, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
		return
	}

	mu.Lock()
	journal = append(journal, entry{Method: method, Target: target, OpKey: strings.Contains(auth, opKeyMarker), Auth: auth})
	mu.Unlock()
	body := `{"ok":true,"observer":true}`
	fmt.Fprintf(conn, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s", len(body), body)
}

func main() {
	ln, err := net.Listen("tcp", ":8080")
	if err != nil {
		panic(err)
	}
	fmt.Println("observer listening :8080")
	for {
		c, err := ln.Accept()
		if err != nil {
			continue
		}
		go handle(c)
	}
}
