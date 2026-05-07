import { useState, useCallback } from 'react';
import { createFileRoute, redirect } from '@tanstack/react-router';
import { Users as UsersIcon, Search } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { useAuth, type User } from '@/hooks/useAuth';
import { UserTable } from '@/components/admin/UserTable';
import { useUsers, useUpdateUserRole, useUpdateUserStatus } from '@/hooks/useAdmin';

export const Route = createFileRoute('/admin/users')({
  beforeLoad: ({ context }) => {
    const user = context.queryClient.getQueryData<User>(['auth', 'me']);
    // Only redirect if we have cached user data and they're not admin.
    // If data isn't cached yet, let the component's ProtectedRoute handle it.
    if (user !== undefined && user.role !== 'admin') {
      throw redirect({ to: '/sessions' });
    }
  },
  component: UserManagementPage,
});

const roleFilterTabs = [
  { value: '', label: 'All' },
  { value: 'admin', label: 'Admin' },
  { value: 'manager', label: 'Manager' },
  { value: 'operator', label: 'Operator' },
  { value: 'viewer', label: 'Viewer' },
  { value: 'auditor', label: 'Auditor' },
];

const inputClass =
  'rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

function UserManagementPage() {
  const { user } = useAuth();
  const [roleFilter, setRoleFilter] = useState('');
  const [emailSearch, setEmailSearch] = useState('');
  const [page, setPage] = useState(0);
  const pageSize = 20;

  const { data, isLoading, error } = useUsers({
    role: roleFilter || undefined,
    offset: page * pageSize,
    limit: pageSize,
  });

  const updateRoleMut = useUpdateUserRole();
  const updateStatusMut = useUpdateUserStatus();

  // Client-side email filter refinement
  const users = (data?.users ?? []).filter((u) =>
    emailSearch
      ? u.email.toLowerCase().includes(emailSearch.toLowerCase())
      : true,
  );
  const total = data?.total ?? 0;
  const totalPages = Math.ceil(total / pageSize);

  const handleRoleChange = useCallback(
    (userId: string, newRole: string) => {
      updateRoleMut.mutate({ id: userId, role: newRole });
    },
    [updateRoleMut],
  );

  const handleStatusToggle = useCallback(
    (userId: string, isActive: boolean) => {
      updateStatusMut.mutate({ id: userId, isActive });
    },
    [updateStatusMut],
  );

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">
              User Management
            </h1>
            <p className="mt-1 text-sm text-text-secondary">
              {total > 0
                ? `${total} total user${total !== 1 ? 's' : ''}`
                : 'Manage users, roles, and access'}
            </p>
          </div>
        </div>

        {/* Info banner */}
        <div className="rounded border border-accent-blue/20 bg-accent-blue/5 px-4 py-3 text-xs text-text-secondary">
          Default role for new SSO users is <strong className="text-text-primary">Viewer</strong>. Admins can promote users here.
        </div>

        {/* Error state */}
        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load users.
          </div>
        )}

        {/* Filters bar */}
        <div className="flex flex-wrap items-center gap-3">
          {/* Role tabs */}
          <div className="flex gap-1 rounded bg-bg-elevated p-1">
            {roleFilterTabs.map((tab) => (
              <button
                key={tab.value}
                onClick={() => {
                  setRoleFilter(tab.value);
                  setPage(0);
                }}
                className={`rounded px-2.5 py-1 text-xs font-medium transition-colors ${
                  roleFilter === tab.value
                    ? 'bg-accent-blue text-white'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Email search */}
          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-text-disabled" />
            <input
              type="text"
              className={`${inputClass} pl-7`}
              placeholder="Filter by email..."
              value={emailSearch}
              onChange={(e) => setEmailSearch(e.target.value)}
            />
          </div>
        </div>

        {/* Loading state */}
        {isLoading && (
          <div className="space-y-2">
            {Array.from({ length: 5 }).map((_, i) => (
              <div
                key={i}
                className="h-12 animate-pulse rounded bg-bg-elevated"
              />
            ))}
          </div>
        )}

        {/* User table */}
        {!isLoading && (
          <UserTable
            users={users}
            currentUserId={user?.id}
            onRoleChange={handleRoleChange}
            onStatusToggle={handleStatusToggle}
          />
        )}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between">
            <span className="text-xs text-text-disabled">
              Page {page + 1} of {totalPages}
            </span>
            <div className="flex gap-2">
              <button
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={page === 0}
                className="rounded border border-border-subtle bg-bg-elevated px-3 py-1 text-xs text-text-secondary hover:bg-bg-hover hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Previous
              </button>
              <button
                onClick={() =>
                  setPage((p) => Math.min(totalPages - 1, p + 1))
                }
                disabled={page >= totalPages - 1}
                className="rounded border border-border-subtle bg-bg-elevated px-3 py-1 text-xs text-text-secondary hover:bg-bg-hover hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>
    </ProtectedRoute>
  );
}
