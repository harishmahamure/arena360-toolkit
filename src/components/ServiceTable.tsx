import type { ServiceItem } from "../types";

interface ServiceTableProps {
  services: ServiceItem[];
  selected: Set<string>;
  onToggle: (name: string) => void;
  categoryFilter: string;
  onCategoryFilterChange: (value: string) => void;
}

const categoryColors: Record<string, string> = {
  essential: "essential",
  gaming_safe_disable: "safe-disable",
  contextual: "contextual",
  unknown: "unknown",
};

export function ServiceTable({
  services,
  selected,
  onToggle,
  categoryFilter,
  onCategoryFilterChange,
}: ServiceTableProps) {
  const filtered =
    categoryFilter === "all"
      ? services
      : services.filter((s) => s.category === categoryFilter);

  return (
    <div className="service-table-wrap">
      <div className="table-toolbar">
        <select
          value={categoryFilter}
          onChange={(e) => onCategoryFilterChange(e.target.value)}
        >
          <option value="all">All categories</option>
          <option value="gaming_safe_disable">Safe to disable</option>
          <option value="contextual">Contextual</option>
          <option value="essential">Essential</option>
          <option value="unknown">Unknown</option>
        </select>
        <span className="muted">{filtered.length} services</span>
      </div>
      <table className="service-table">
        <thead>
          <tr>
            <th></th>
            <th>Service</th>
            <th>Status</th>
            <th>Start</th>
            <th>Category</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((svc) => (
            <tr key={svc.name}>
              <td>
                <input
                  type="checkbox"
                  checked={selected.has(svc.name)}
                  onChange={() => onToggle(svc.name)}
                  disabled={svc.category === "essential"}
                />
              </td>
              <td>
                <strong>{svc.display_name}</strong>
                <div className="muted small">{svc.name}</div>
              </td>
              <td>{svc.status}</td>
              <td>{svc.start_type}</td>
              <td>
                <span className={`badge ${categoryColors[svc.category] ?? "unknown"}`}>
                  {svc.category.replace(/_/g, " ")}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
