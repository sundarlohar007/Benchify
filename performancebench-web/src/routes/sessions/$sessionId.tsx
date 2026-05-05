import { createFileRoute } from '@tanstack/react-router';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export const Route = createFileRoute('/sessions/$sessionId')({
  component: () => (
    <ProtectedRoute>
      <div className="p-6">
        <h1 className="text-xl font-semibold text-text-primary">
          Session Detail
        </h1>
        <p className="mt-2 text-text-secondary">
          Session detail view will be built in Task 3.
        </p>
      </div>
    </ProtectedRoute>
  ),
});
