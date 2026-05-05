import { createFileRoute } from '@tanstack/react-router';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export const Route = createFileRoute('/live')({
  component: () => (
    <ProtectedRoute>
      <div className="p-6">
        <h1 className="text-xl font-semibold text-text-primary">Live</h1>
        <p className="mt-2 text-text-secondary">
          Live overlay will be built in Plan 03-06.
        </p>
      </div>
    </ProtectedRoute>
  ),
});
