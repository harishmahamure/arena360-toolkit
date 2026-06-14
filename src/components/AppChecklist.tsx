import type { BloatItem } from "../types";

interface AppChecklistProps {
  items: BloatItem[];
  selected: Set<string>;
  onToggle: (id: string) => void;
  onSelectAll: () => void;
  onClearAll: () => void;
  filter: string;
  onFilterChange: (value: string) => void;
}

export function AppChecklist({
  items,
  selected,
  onToggle,
  onSelectAll,
  onClearAll,
  filter,
  onFilterChange,
}: AppChecklistProps) {
  const filtered = items.filter(
    (item) =>
      item.name.toLowerCase().includes(filter.toLowerCase()) ||
      item.id.toLowerCase().includes(filter.toLowerCase()),
  );

  return (
    <div className="checklist">
      <div className="checklist-toolbar">
        <input
          type="search"
          placeholder="Search apps..."
          value={filter}
          onChange={(e) => onFilterChange(e.target.value)}
        />
        <button className="btn secondary" onClick={onSelectAll}>
          Select installed
        </button>
        <button className="btn secondary" onClick={onClearAll}>
          Clear
        </button>
      </div>
      <div className="checklist-items">
        {filtered.map((item) => (
          <label key={item.id} className="checklist-item">
            <input
              type="checkbox"
              checked={selected.has(item.id)}
              onChange={() => onToggle(item.id)}
              disabled={!item.installed}
            />
            <span className="item-name">{item.name}</span>
            <span className={`badge ${item.installed ? "installed" : "missing"}`}>
              {item.installed ? "Installed" : "Not found"}
            </span>
            {item.optional && <span className="badge optional">Optional</span>}
          </label>
        ))}
      </div>
    </div>
  );
}
