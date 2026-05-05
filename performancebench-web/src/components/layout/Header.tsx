import { useAuth, useLogout } from '@/hooks/useAuth';
import { APP_NAME } from '@/lib/constants';
import { LogOut } from 'lucide-react';

export function Header() {
  const { user } = useAuth();
  const logout = useLogout();

  return (
    <header className="flex h-12 items-center justify-between border-b border-border-subtle bg-bg-elevated px-4">
      <h1 className="text-sm font-semibold text-text-primary">{APP_NAME}</h1>

      <div className="flex items-center gap-3">
        {user && (
          <span className="text-xs text-text-secondary">{user.email}</span>
        )}
        <button
          onClick={() => logout.mutate()}
          className="flex items-center gap-1 rounded px-2 py-1 text-xs text-text-secondary hover:bg-bg-hover hover:text-text-primary"
          title="Sign out"
        >
          <LogOut className="h-3 w-3" />
          Sign out
        </button>
      </div>
    </header>
  );
}
