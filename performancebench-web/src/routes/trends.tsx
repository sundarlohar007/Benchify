import { createFileRoute } from '@tanstack/react-router';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export const Route = createFileRoute('/trends')({
  component: () => (
    <ProtectedRoute>
      <div className="p-6">
        <h1 className="text-xl font-semibold text-text-primary">Trends</h1>
        <p className="mt-2 text-text-secondary">
          Trends Explorer will be built in Plan 03-04.
        </p>
      </div>
    </ProtectedRoute>
  ),
});
