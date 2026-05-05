import { createFileRoute } from '@tanstack/react-router';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

export const Route = createFileRoute('/alerts')({
  component: () => (
    <ProtectedRoute>
      <div className="p-6">
        <h1 className="text-xl font-semibold text-text-primary">Alerts</h1>
        <p className="mt-2 text-text-secondary">
          Alert configuration will be built in Plan 03-05.
        </p>
      </div>
    </ProtectedRoute>
  ),
});
