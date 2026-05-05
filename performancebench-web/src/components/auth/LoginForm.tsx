import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod/v4';
import { zodResolver } from '@hookform/resolvers/zod';
import { useLogin } from '@/hooks/useAuth';
import { ApiError } from '@/lib/api';
import { APP_NAME } from '@/lib/constants';

const loginSchema = z.object({
  email: z.string().email('Please enter a valid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

type LoginFormData = z.infer<typeof loginSchema>;

export function LoginForm() {
  const login = useLogin();
  const [serverError, setServerError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = (data: LoginFormData) => {
    setServerError(null);
    login.mutate(data, {
      onError: (error) => {
        if (error instanceof ApiError) {
          setServerError(error.message);
        } else {
          setServerError('Connection failed. Ensure the server is running.');
        }
      },
    });
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-bg-base">
      <div className="w-full max-w-sm rounded-lg border border-border-subtle bg-bg-elevated p-8 shadow-lg">
        <h1 className="mb-1 text-center text-xl font-semibold text-text-primary">
          {APP_NAME}
        </h1>
        <p className="mb-6 text-center text-sm text-text-secondary">
          Sign in to your dashboard
        </p>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label
              htmlFor="email"
              className="mb-1 block text-sm text-text-secondary"
            >
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              className="w-full rounded border border-border-subtle bg-bg-input px-3 py-2 text-sm text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none"
              placeholder="you@example.com"
              {...register('email')}
            />
            {errors.email && (
              <p className="mt-1 text-xs text-accent-danger">
                {errors.email.message}
              </p>
            )}
          </div>

          <div>
            <label
              htmlFor="password"
              className="mb-1 block text-sm text-text-secondary"
            >
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              className="w-full rounded border border-border-subtle bg-bg-input px-3 py-2 text-sm text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none"
              placeholder="Enter your password"
              {...register('password')}
            />
            {errors.password && (
              <p className="mt-1 text-xs text-accent-danger">
                {errors.password.message}
              </p>
            )}
          </div>

          {serverError && (
            <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-3 py-2 text-sm text-accent-danger">
              {serverError}
            </div>
          )}

          <button
            type="submit"
            disabled={isSubmitting || login.isPending}
            className="w-full rounded bg-accent-blue px-4 py-2 text-sm font-medium text-white transition-colors hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {login.isPending ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
