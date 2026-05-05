package server

import (
	"encoding/json"
	"net/http"
)

// handleGetPreferences returns the authenticated user's preferences as a
// flat string-to-string map. Keys are arbitrary; current users are
// `selected_facility_id` (Phase 1 of the UI restructure). A null value
// means the preference is unset.
func (s *Server) handleGetPreferences(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}

	rows, err := s.db.QueryRows(
		`SELECT key, value FROM app_user_preferences WHERE user_id = ?`,
		user.ID,
	)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	prefs := make(map[string]any, len(rows))
	for _, row := range rows {
		k, _ := row["key"].(string)
		prefs[k] = row["value"]
	}
	writeJSON(w, prefs)
}

// handlePatchPreferences upserts the keys in the request body. A null
// value deletes the preference. Returns the updated preference map.
func (s *Server) handlePatchPreferences(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}

	var body map[string]*string
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	for key, value := range body {
		if value == nil {
			err := s.db.ExecParams(
				`DELETE FROM app_user_preferences WHERE user_id = ? AND key = ?`,
				user.ID, key,
			)
			if err != nil {
				writeError(w, err.Error(), http.StatusInternalServerError)
				return
			}
			continue
		}
		err := s.db.ExecParams(
			`INSERT INTO app_user_preferences (user_id, key, value, updated_at)
			 VALUES (?, ?, ?, datetime('now'))
			 ON CONFLICT(user_id, key) DO UPDATE SET
			     value = excluded.value,
			     updated_at = excluded.updated_at`,
			user.ID, key, *value,
		)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}

	s.handleGetPreferences(w, r)
}
