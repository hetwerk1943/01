/**
 * ForgotPassword page – sends a reset link to the user's email.
 */
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Link } from 'react-router-dom';
import { authApi } from '../api';
import { useState } from 'react';

const schema = z.object({
  email: z.string().email('Invalid email'),
});
type FormData = z.infer<typeof schema>;

export function ForgotPasswordPage() {
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({ resolver: zodResolver(schema) });

  const onSubmit = async (data: FormData) => {
    try {
      setError('');
      await authApi.forgotPassword(data.email);
      setSent(true);
    } catch {
      setError('Something went wrong. Please try again.');
    }
  };

  if (sent) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="card w-full max-w-md text-center">
          <h1 className="text-2xl font-bold mb-4">Check Your Email</h1>
          <p className="text-gray-600">
            If that email is registered, we sent a password reset link.
          </p>
          <Link to="/login" className="btn-primary inline-block mt-6">
            Back to Login
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="card w-full max-w-md">
        <h1 className="text-2xl font-bold text-center mb-6">Forgot Password</h1>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Email Address
            </label>
            <input
              type="email"
              {...register('email')}
              className="input"
              placeholder="you@example.com"
            />
            {errors.email && (
              <p className="text-red-500 text-xs mt-1">{errors.email.message}</p>
            )}
          </div>

          <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
            {isSubmitting ? 'Sending…' : 'Send Reset Link'}
          </button>
        </form>

        <p className="text-center text-sm text-gray-500 mt-4">
          Remembered it?{' '}
          <Link to="/login" className="text-primary-600 hover:underline">
            Sign In
          </Link>
        </p>
      </div>
    </div>
  );
}
