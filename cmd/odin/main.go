package main

import (
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"syscall"

	odin "github.com/asgardehs/odin"
	"github.com/asgardehs/odin/internal/server"
)

var version = "dev"

func main() {
	// Extract the dist/ subdirectory from the embedded FS.
	dist, err := fs.Sub(odin.FrontendDist, "frontend/dist")
	if err != nil {
		log.Fatalf("embedded frontend not found: %v", err)
	}

	addr := "odin.localhost:8080"
	srv := server.New(dist)

	// Graceful shutdown on interrupt.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		fmt.Printf("Odin %s listening on http://%s\n", version, addr)
		if err := srv.ListenAndServe(addr); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	// Open browser after server starts.
	go openBrowser("http://" + addr)

	<-stop
	fmt.Println("\nShutting down.")
}

// openBrowser launches the user's default browser.
func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	}
	if cmd != nil {
		cmd.Start()
	}
}
