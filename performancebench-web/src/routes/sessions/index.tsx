import { createFileRoute } from '@tanstack/react-router';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export const Route = createFileRoute('/sessions/')({
  component: () => (
    <ProtectedRoute>
      <div className="p-6">
        <h1 className="text-xl font-semibold text-text-primary">Sessions</h1>
        <p className="mt-2 text-text-secondary">
          Session list will be built in Task 2.
        </p>
      </div>
    </ProtectedRoute>
  ),
});
