package main

import (
	"embed"
	"log"
	"net/http"
)

//go:embed index.html
var htmlFiles embed.FS

func main() {
	// "/" 경로에 대한 핸들러를 등록합니다.
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		data, err := htmlFiles.ReadFile("index.html")
		if err != nil {
			http.Error(w, "internal server error", http.StatusInternalServerError)
			log.Printf("index.html 읽기 실패: %v", err)
			return
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if _, err := w.Write(data); err != nil {
			log.Printf("응답 전송 실패: %v", err)
		}
	})

	// 8080 포트에서 서버를 시작합니다.
	log.Println("서버 시작: http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}
