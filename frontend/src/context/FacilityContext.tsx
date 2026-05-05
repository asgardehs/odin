import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from 'react';
import { api } from '../api';
import { useAuth } from './AuthContext';

export interface Facility {
  id: number;
  name: string;
  is_active: number;
}

interface FacilityState {
  facilities: Facility[];
  selectedId: number | null;
  selected: Facility | null;
  loading: boolean;
  setSelectedId: (id: number | null) => Promise<void>;
}

const PREF_KEY = 'selected_facility_id';

const FacilityContext = createContext<FacilityState | null>(null);

export function FacilityProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [facilities, setFacilities] = useState<Facility[]>([]);
  const [selectedId, setSelectedIdState] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);

  // Reset and reload whenever the authenticated user changes (login / logout).
  useEffect(() => {
    if (!user) {
      setFacilities([]);
      setSelectedIdState(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    Promise.all([
      api.get<{ rows: Facility[] }>('/api/establishments?per_page=500'),
      api.get<Record<string, string | null>>('/api/me/preferences'),
    ])
      .then(([list, prefs]) => {
        setFacilities(list.rows ?? []);
        const raw = prefs[PREF_KEY];
        const parsed = raw == null ? null : Number(raw);
        setSelectedIdState(Number.isFinite(parsed) ? parsed : null);
      })
      .catch(() => {
        setFacilities([]);
        setSelectedIdState(null);
      })
      .finally(() => setLoading(false));
  }, [user]);

  const setSelectedId = useCallback(async (id: number | null) => {
    setSelectedIdState(id);
    try {
      await api.patch('/api/me/preferences', {
        [PREF_KEY]: id == null ? null : String(id),
      });
    } catch {
      // Best-effort persistence — the in-memory selection still applies
      // for this session even if the server rejected the write.
    }
  }, []);

  const selected = facilities.find(f => f.id === selectedId) ?? null;

  return (
    <FacilityContext.Provider
      value={{ facilities, selectedId, selected, loading, setSelectedId }}
    >
      {children}
    </FacilityContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components -- hook and provider are intentionally co-located
export function useFacility(): FacilityState {
  const ctx = useContext(FacilityContext);
  if (!ctx) throw new Error('useFacility must be used within FacilityProvider');
  return ctx;
}
