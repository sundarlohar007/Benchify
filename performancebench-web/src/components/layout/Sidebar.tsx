import { useState } from 'react';
import { Link } from '@tanstack/react-router';
import {
  LayoutList,
  TrendingUp,
  Filter,
  FileText,
  Bell,
  Settings,
  ChevronLeft,
  ChevronRight,
  PanelLeftOpen,
  PanelLeftClose,
} from 'lucide-react';

const navItems = [
  { to: '/sessions', label: 'Sessions', icon: LayoutList },
  { to: '/trends', label: 'Trends', icon: TrendingUp },
  { to: '/lenses', label: 'Lenses', icon: Filter },
  { to: '/reports', label: 'Reports', icon: FileText },
  { to: '/alerts', label: 'Alerts', icon: Bell },
  { to: '/settings', label: 'Settings', icon: Settings },
];

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <aside
      className={`flex h-screen flex-col border-r border-border-subtle bg-bg-sidebar transition-all duration-200 ${
        collapsed ? 'w-16' : 'w-56'
      }`}
    >
      {/* Toggle button */}
      <div className="flex items-center justify-end px-3 py-3">
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="rounded p-1 text-text-secondary hover:bg-bg-hover hover:text-text-primary"
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? (
            <PanelLeftOpen className="h-4 w-4" />
          ) : (
            <PanelLeftClose className="h-4 w-4" />
          )}
        </button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 px-2">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <Link
              key={item.to}
              to={item.to}
              activeProps={{
                className:
                  'bg-bg-selected border-l-2 border-accent-blue text-text-primary',
              }}
              inactiveProps={{
                className:
                  'border-l-2 border-transparent text-text-secondary hover:bg-bg-hover hover:text-text-primary',
              }}
              className={`flex items-center gap-3 rounded-r px-3 py-2 text-sm transition-colors`}
            >
              <Icon className="h-4 w-4 flex-shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          );
        })}
      </nav>

      {/* Footer collapse hint */}
      {!collapsed && (
        <div className="border-t border-border-subtle px-3 py-2">
          <button
            onClick={() => setCollapsed(true)}
            className="flex w-full items-center gap-2 text-xs text-text-disabled hover:text-text-secondary"
          >
            <ChevronLeft className="h-3 w-3" />
            Collapse
          </button>
        </div>
      )}
    </aside>
  );
}
