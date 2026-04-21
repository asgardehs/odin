const TOKEN_KEY = 'odin_session_token';

// --- Token storage (localStorage) ---

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

// --- Core fetch wrapper ---

/**
 * Fetch wrapper that attaches the Bearer token to every request and
 * fires a custom event on 401 so the auth context can react.
 */
export async function apiFetch(url: string, options: RequestInit = {}): Promise<Response> {
  const token = getToken();
  const headers = new Headers(options.headers);

  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  // Let the browser set Content-Type for FormData (multipart boundary);
  // otherwise default to JSON when a body is present.
  if (options.body && !headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  const res = await fetch(url, { ...options, headers });

  if (res.status === 401 && token) {
    clearToken();
    window.dispatchEvent(new Event('odin:session-expired'));
  }

  return res;
}

// --- Typed convenience methods ---

export const api = {
  async get<T>(url: string): Promise<T> {
    const res = await apiFetch(url);
    if (!res.ok) throw new ApiError(res.status, await errorBody(res));
    return res.json();
  },

  async post<T>(url: string, body?: unknown): Promise<T> {
    const res = await apiFetch(url, {
      method: 'POST',
      body: body != null ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) throw new ApiError(res.status, await errorBody(res));
    return res.json();
  },

  async put<T>(url: string, body: unknown): Promise<T> {
    const res = await apiFetch(url, {
      method: 'PUT',
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new ApiError(res.status, await errorBody(res));
    return res.json();
  },

  async del(url: string): Promise<void> {
    const res = await apiFetch(url, { method: 'DELETE' });
    if (!res.ok) throw new ApiError(res.status, await errorBody(res));
  },
};

// --- Error type ---

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function errorBody(res: Response): Promise<string> {
  try {
    const body = await res.json();
    return body.error || res.statusText;
  } catch {
    return res.statusText;
  }
}
