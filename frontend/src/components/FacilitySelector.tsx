import { useFacility } from '../context/FacilityContext';

interface Props {
  collapsed: boolean;
}

export default function FacilitySelector({ collapsed }: Props) {
  const { facilities, selectedId, selected, loading, setSelectedId } = useFacility();

  if (collapsed) {
    return (
      <div
        className="h-10 flex items-center justify-center text-sm text-[var(--color-comment)]"
        title={selected ? selected.name : 'All facilities'}
      >
        🏭
      </div>
    );
  }

  return (
    <div className="px-3 py-2">
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-comment)] mb-1">
        Facility
      </div>
      <select
        value={selectedId ?? ''}
        disabled={loading}
        onChange={e => {
          const v = e.target.value;
          setSelectedId(v === '' ? null : Number(v));
        }}
        className="w-full h-8 px-2 text-sm rounded bg-[var(--color-bg-lighter)] text-[var(--color-fg)] border border-[var(--color-current-line)] focus:border-[var(--color-purple)] focus:outline-none"
      >
        <option value="">All facilities</option>
        {facilities.map(f => (
          <option key={f.id} value={f.id}>
            {f.name}
          </option>
        ))}
      </select>
    </div>
  );
}
