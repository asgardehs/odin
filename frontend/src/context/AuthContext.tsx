import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import { api, setToken, clearToken, getToken } from '../api';

export interface User {
  id: number;
  username: string;
  display_name: string;
  role: string;
  is_active: boolean;
  has_security_questions: boolean;
  created_at: string;
  updated_at: string;
  last_login_at?: string;
}

interface AuthState {
  user: User | null;
  readonly: boolean;
  loading: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  enterReadonly: () => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [readonlyMode, setReadonlyMode] = useState(false);
  const [loading, setLoading] = useState(true);

  // Validate existing token on mount.
  useEffect(() => {
    const token = getToken();
    if (!token) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setLoading(false);
      return;
    }

    api.get<User>('/api/auth/me')
      .then(setUser)
      .catch(() => clearToken())
      .finally(() => setLoading(false));
  }, []);

  // Listen for 401s from apiFetch — session expired elsewhere.
  useEffect(() => {
    const handler = () => {
      setUser(null);
      setReadonlyMode(false);
    };
    window.addEventListener('odin:session-expired', handler);
    return () => window.removeEventListener('odin:session-expired', handler);
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    const res = await api.post<{ token: string; user: User }>(
      '/api/auth/login',
      { username, password },
    );
    setToken(res.token);
    setUser(res.user);
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.post('/api/auth/logout', {});
    } catch {
      // Best-effort — clear local state regardless.
    }
    clearToken();
    setUser(null);
    setReadonlyMode(false);
  }, []);

  const enterReadonly = useCallback(() => setReadonlyMode(true), []);

  return (
    <AuthContext.Provider value={{ user, readonly: readonlyMode, loading, login, logout, enterReadonly }}>
      {children}
    </AuthContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components -- hook and provider are intentionally co-located
export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
