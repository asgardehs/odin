import { useState, useCallback } from 'react';
import { api, ApiError } from '../api';

type Method = 'POST' | 'PUT' | 'DELETE';

interface MutationState {
  loading: boolean;
  error: string | null;
}

/**
 * Wrapper around api.post/put/del that tracks loading + error state.
 *
 * Returns {mutate, loading, error, reset}. Throws ApiError on failure
 * so the caller can branch on .status.
 */
export function useEntityMutation<TResult = unknown>() {
  const [state, setState] = useState<MutationState>({ loading: false, error: null });

  const mutate = useCallback(async (method: Method, url: string, body?: unknown): Promise<TResult> => {
    setState({ loading: true, error: null });
    try {
      let result: unknown;
      if (method === 'POST') {
        result = await api.post<TResult>(url, body);
      } else if (method === 'PUT') {
        result = await api.put<TResult>(url, body);
      } else {
        await api.del(url);
        result = undefined;
      }
      setState({ loading: false, error: null });
      return result as TResult;
    } catch (e) {
      const message = e instanceof ApiError ? e.message : e instanceof Error ? e.message : 'Request failed';
      setState({ loading: false, error: message });
      throw e;
    }
  }, []);

  const reset = useCallback(() => setState({ loading: false, error: null }), []);

  return { mutate, loading: state.loading, error: state.error, reset };
}
