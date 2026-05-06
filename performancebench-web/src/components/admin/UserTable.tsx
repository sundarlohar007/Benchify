import { useMemo } from 'react';
import { RoleBadge } from './RoleBadge';
import type { UserDetail } from '@/hooks/useAdmin';

interface UserTableProps {
  users: UserDetail[];
  currentUserId?: string;
  onRoleChange: (userId: string, newRole: string) => void;
  onStatusToggle: (userId: string, isActive: boolean) => void;
}

const ROLE_OPTIONS = [
  { value: 'admin', label: 'Admin' },
  { value: 'manager', label: 'Manager' },
  { value: 'operator', label: 'Operator' },
  { value: 'viewer', label: 'Viewer' },
  { value: 'auditor', label: 'Auditor' },
];

const authSourceLabel = (source: string): string => {
  switch (source) {
    case 'local':
      return 'Local';
    case 'oidc':
      return 'OIDC';
    case 'saml':
      return 'SAML';
    case 'ldap':
      return 'LDAP';
    default:
      return source;
  }
};

const authSourceColor = (source: string): string => {
  switch (source) {
    case 'local':
      return 'bg-bg-input text-text-secondary';
    case 'oidc':
      return 'bg-accent-blue/15 text-accent-blue';
    case 'saml':
      return 'bg-accent-warning/15 text-accent-warning';
    case 'ldap':
      return 'bg-purple-500/15 text-purple-400';
    default:
      return 'bg-bg-input text-text-disabled';
  }
};

export function UserTable({
  users,
  currentUserId,
  onRoleChange,
  onStatusToggle,
}: UserTableProps) {
  const inputClass =
    'rounded border border-border-subtle bg-bg-input px-2 py-1 text-xs text-text-primary focus:border-border-focus focus:outline-none';

  if (users.length === 0) {
    return (
      <div className="flex flex-col items-center py-12 text-text-disabled">
        <svg
          className="mb-3 h-8 w-8"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"
          />
        </svg>
        <p>No users found</p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-border-subtle text-text-disabled">
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Email
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Display Name
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Role
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Auth Source
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Status
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr
              key={user.id}
              className="border-b border-border-subtle transition-colors hover:bg-bg-hover"
            >
              <td className="px-3 py-2.5">
                <span className="text-text-primary">{user.email}</span>
              </td>
              <td className="px-3 py-2.5">
                <span className="text-text-secondary">
                  {user.display_name || '—'}
                </span>
              </td>
              <td className="px-3 py-2.5">
                {user.id === currentUserId ? (
                  <RoleBadge role={user.role} />
                ) : (
                  <select
                    className={inputClass}
                    value={user.role}
                    onChange={(e) => onRoleChange(user.id, e.target.value)}
                  >
                    {ROLE_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                )}
              </td>
              <td className="px-3 py-2.5">
                <span
                  className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${authSourceColor(user.auth_source)}`}
                >
                  {authSourceLabel(user.auth_source)}
                </span>
              </td>
              <td className="px-3 py-2.5">
                <button
                  onClick={() =>
                    onStatusToggle(user.id, !user.is_active)
                  }
                  disabled={user.id === currentUserId}
                  className={`inline-flex items-center gap-1 rounded px-2 py-0.5 text-xs font-medium transition-colors ${
                    user.is_active
                      ? 'bg-accent-success/15 text-accent-success hover:bg-accent-success/25'
                      : 'bg-accent-danger/15 text-accent-danger hover:bg-accent-danger/25'
                  } disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  {user.is_active ? 'Active' : 'Inactive'}
                </button>
              </td>
              <td className="px-3 py-2.5">
                {user.id !== currentUserId && (
                  <span className="text-xs text-text-disabled">
                    {user.is_active ? 'Click to deactivate' : 'Click to activate'}
                  </span>
                )}
                {user.id === currentUserId && (
                  <span className="text-xs text-text-disabled">You</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
