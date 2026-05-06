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
  Shield,
  ScrollText,
  Users,
  Key,
} from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

const navItems = [
  { to: '/sessions', label: 'Sessions', icon: LayoutList },
  { to: '/trends', label: 'Trends', icon: TrendingUp },
  { to: '/lenses', label: 'Lenses', icon: Filter },
  { to: '/reports', label: 'Reports', icon: FileText },
  { to: '/alerts', label: 'Alerts', icon: Bell },
];

// Settings sub-items
const settingsItems = [
  { to: '/settings', label: 'General', icon: Settings },
  { to: '/settings/sso', label: 'SSO', icon: Key, adminOnly: true },
];

// Admin section items
const adminItems = [
  { to: '/admin/users', label: 'Users', icon: Users, adminOnly: true },
  { to: '/admin/audit', label: 'Audit', icon: ScrollText, roles: ['admin', 'auditor'] },
];

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const { user, isAdmin, isAuditor } = useAuth();

  const canSeeSettingsItem = (item: { adminOnly?: boolean }) =>
    !item.adminOnly || isAdmin;

  const canSeeAdminItem = (item: { adminOnly?: boolean; roles?: string[] }) => {
    if (item.adminOnly) return isAdmin;
    if (item.roles) return item.roles.includes(user?.role ?? '');
    return false;
  };

  const hasAdminAccess = adminItems.some((item) => canSeeAdminItem(item));

  const linkClass = (isActive: boolean) =>
    `flex items-center gap-3 rounded-r px-3 py-2 text-sm transition-colors ${
      isActive
        ? 'bg-bg-selected border-l-2 border-accent-blue text-text-primary'
        : 'border-l-2 border-transparent text-text-secondary hover:bg-bg-hover hover:text-text-primary'
    }`;

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
      <nav className="flex-1 space-y-1 px-2 overflow-y-auto">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <Link
              key={item.to}
              to={item.to}
              activeProps={{ className: linkClass(true) }}
              inactiveProps={{ className: linkClass(false) }}
              className={linkClass(false)}
            >
              <Icon className="h-4 w-4 flex-shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          );
        })}

        {/* Settings sub-items */}
        {!collapsed && (
          <div className="pt-2">
            <p className="px-3 py-1 text-[10px] uppercase tracking-widest text-text-disabled">
              Settings
            </p>
          </div>
        )}
        {settingsItems
          .filter(canSeeSettingsItem)
          .map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.to}
                to={item.to}
                activeProps={{ className: linkClass(true) }}
                inactiveProps={{ className: linkClass(false) }}
                className={linkClass(false)}
              >
                <Icon className="h-4 w-4 flex-shrink-0" />
                {!collapsed && <span>{item.label}</span>}
              </Link>
            );
          })}

        {/* Admin section (conditional) */}
        {hasAdminAccess && (
          <>
            {!collapsed && (
              <div className="pt-2">
                <p className="px-3 py-1 text-[10px] uppercase tracking-widest text-text-disabled">
                  Admin
                </p>
              </div>
            )}
            {adminItems
              .filter(canSeeAdminItem)
              .map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.to}
                    to={item.to}
                    activeProps={{ className: linkClass(true) }}
                    inactiveProps={{ className: linkClass(false) }}
                    className={linkClass(false)}
                  >
                    <Icon className="h-4 w-4 flex-shrink-0" />
                    {!collapsed && <span>{item.label}</span>}
                  </Link>
                );
              })}
          </>
        )}
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
