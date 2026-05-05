import { createFileRoute } from '@tanstack/react-router';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export const Route = createFileRoute('/settings/')({
  component: () => (
    <ProtectedRoute>
      <div className="p-6">
        <h1 className="text-xl font-semibold text-text-primary">Settings</h1>
        <p className="mt-2 text-text-secondary">
          Server settings will be built in a future plan.
        </p>
      </div>
    </ProtectedRoute>
  ),
});
