package server

import (
	"io/fs"
	"net/http"
)

// Server is the Odin HTTP server.
type Server struct {
	mux      *http.ServeMux
	frontend fs.FS
}

// New creates a server that serves the embedded frontend and API routes.
func New(frontend fs.FS) *Server {
	s := &Server{
		mux:      http.NewServeMux(),
		frontend: frontend,
	}
	s.routes()
	return s
}

// ListenAndServe starts the HTTP server.
func (s *Server) ListenAndServe(addr string) error {
	return http.ListenAndServe(addr, s.mux)
}

// routes registers all HTTP routes.
func (s *Server) routes() {
	// API routes.
	s.mux.HandleFunc("GET /api/health", s.handleHealth)

	// Frontend: serve embedded SPA. Non-file paths fall back to index.html
	// so React Router can handle client-side routes.
	s.mux.Handle("/", spaHandler(s.frontend))
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

// spaHandler serves static files from the FS, falling back to index.html
// for paths that don't match a file (client-side routing).
func spaHandler(content fs.FS) http.Handler {
	fileServer := http.FileServer(http.FS(content))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Try to serve the file directly.
		path := r.URL.Path
		if path == "/" {
			fileServer.ServeHTTP(w, r)
			return
		}

		// Check if the file exists in the embedded FS.
		f, err := content.Open(path[1:]) // strip leading /
		if err == nil {
			f.Close()
			fileServer.ServeHTTP(w, r)
			return
		}

		// File not found — serve index.html for client-side routing.
		r.URL.Path = "/"
		fileServer.ServeHTTP(w, r)
	})
}
