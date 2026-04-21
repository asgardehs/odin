import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { api } from '../../api';

// Permit type IDs seeded in module_permits_licenses.sql under the
// 'CWA_Framework' regulatory_framework_code.
const CWA_PERMIT_TYPE_IDS = new Set([10, 11, 12, 13, 14]);
// 10 NPDES_INDIVIDUAL · 11 NPDES_GENERAL · 12 NPDES_STORMWATER
// 13 PRETREATMENT    · 14 GWDP (Groundwater Discharge)

type PermitRow = Record<string, unknown>;

interface PermitTypeOption {
  id: number;
  type_code: string;
  type_name: string;
}

interface PagedResult<T> {
  data: T[];
  total: number;
}

function expiryStyle(s: string): { label: string; color: string } {
  if (!s) return { label: '—', color: 'var(--color-comment)' };
  const daysLeft = Math.ceil((new Date(s).getTime() - Date.now()) / 86_400_000);
  const color =
    daysLeft < 0
      ? 'var(--color-fn-red)'
      : daysLeft <= 90
      ? 'var(--color-fn-orange)'
      : 'var(--color-fg)';
  return { label: s, color };
}

export default function PermitListNPDES() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<PermitRow[] | null>(null);
  const [permitTypes, setPermitTypes] = useState<Map<number, PermitTypeOption>>(new Map());
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      api
        .get<PagedResult<PermitRow>>('/api/permits?per_page=500')
        .then((r) =>
          (r.data ?? []).filter((p) => CWA_PERMIT_TYPE_IDS.has(Number(p.permit_type_id))),
        ),
      api
        .get<PagedResult<PermitTypeOption>>('/api/permit-types?per_page=100')
        .then((r) => r.data ?? []),
    ])
      .then(([filtered, types]) => {
        const typeMap = new Map<number, PermitTypeOption>();
        types.forEach((t) => typeMap.set(t.id, t));
        setPermitTypes(typeMap);
        setRows(filtered);
      })
      .catch((e: Error) => setError(e.message));
  }, []);

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">NPDES Permits</h1>
          <p className="text-xs text-[var(--color-comment)] mt-1">
            Permits under CWA §402 (NPDES individual, general, stormwater, pretreatment, GWDP).
            Filter view of the generic permits table — add / edit via the main{' '}
            <button
              type="button"
              onClick={() => navigate('/permits')}
              className="text-[var(--color-purple)] hover:underline cursor-pointer bg-transparent border-none p-0 text-xs"
            >
              Permits
            </button>{' '}
            page.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate('/permits/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Permit
        </button>
      </div>

      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {error}
        </div>
      )}

      {rows === null ? (
        <p className="text-xs text-[var(--color-comment)]">Loading…</p>
      ) : rows.length === 0 ? (
        <div className="rounded-xl border border-[var(--color-current-line)] p-12 text-center text-sm text-[var(--color-comment)]">
          <p className="mb-3">No NPDES permits yet.</p>
          <button
            type="button"
            onClick={() => navigate('/permits/new')}
            className="text-xs text-[var(--color-purple)] hover:underline"
          >
            + Add the first one
          </button>
        </div>
      ) : (
        <div className="rounded-xl border border-[var(--color-current-line)] bg-[var(--color-bg-light)] overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-[var(--color-bg-dark)]">
              <tr>
                <th className="text-left px-4 py-2.5 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Permit #
                </th>
                <th className="text-left px-4 py-2.5 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Name
                </th>
                <th className="text-left px-4 py-2.5 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Program
                </th>
                <th className="text-left px-4 py-2.5 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Expires
                </th>
                <th className="text-left px-4 py-2.5 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Status
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const exp = expiryStyle(String(r.expiration_date ?? ''));
                const pt = permitTypes.get(Number(r.permit_type_id));
                return (
                  <tr
                    key={String(r.id)}
                    onClick={() => navigate(`/permits/${r.id}`)}
                    className="border-t border-[var(--color-current-line)] hover:bg-[var(--color-bg-lighter)] cursor-pointer transition-colors"
                  >
                    <td className="px-4 py-2.5 text-[var(--color-fg)]">
                      {String(r.permit_number ?? '—')}
                    </td>
                    <td className="px-4 py-2.5 text-[var(--color-fg)]">
                      {String(r.permit_name ?? '—')}
                    </td>
                    <td className="px-4 py-2.5 text-xs text-[var(--color-comment)]">
                      {pt ? `${pt.type_code} — ${pt.type_name}` : `#${String(r.permit_type_id ?? '')}`}
                    </td>
                    <td className="px-4 py-2.5" style={{ color: exp.color }}>
                      {exp.label}
                    </td>
                    <td className="px-4 py-2.5 capitalize text-xs">
                      {String(r.status ?? 'active')}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
