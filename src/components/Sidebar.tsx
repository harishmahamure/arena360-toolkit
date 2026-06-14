export function Sidebar({
  active,
  onNavigate,
}: {
  active: string;
  onNavigate: (page: string) => void;
}) {
  const items = [
    { id: "dashboard", label: "Dashboard", icon: "◉" },
    { id: "lan", label: "LAN", icon: "◎" },
    { id: "uninstall", label: "Uninstall", icon: "✕" },
    { id: "services", label: "Services", icon: "⚙" },
    { id: "privacy", label: "Privacy", icon: "🔒" },
    { id: "winupdate", label: "Windows Update", icon: "⬆" },
    { id: "gaming", label: "Gaming", icon: "🎮" },
    { id: "remote", label: "Remote", icon: "🌐" },
    { id: "logs", label: "Logs", icon: "📋" },
  ];

  return (
    <nav className="sidebar">
      <div className="sidebar-brand">
        <h1>Game Zone</h1>
        <span>Optimizer</span>
      </div>
      <ul>
        {items.map((item) => (
          <li key={item.id}>
            <button
              className={active === item.id ? "active" : ""}
              onClick={() => onNavigate(item.id)}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </button>
          </li>
        ))}
      </ul>
    </nav>
  );
}
