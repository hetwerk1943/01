/**
 * Dashboard page – main user panel after login.
 * Displays welcome message and quick stats.
 */
import { useAuthStore } from '../store/authStore';
import { Navbar } from '../components/Navbar';
import { Link } from 'react-router-dom';

export function DashboardPage() {
  const user = useAuthStore((s) => s.user);

  return (
    <>
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome back, {user?.name}! 👋
          </h1>
          <p className="text-gray-500 mt-1">
            Here's an overview of your account.
          </p>
        </div>

        {/* Stats cards */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-8">
          <div className="card">
            <p className="text-sm text-gray-500">Role</p>
            <p className="text-2xl font-semibold mt-1">{user?.role}</p>
          </div>
          <div className="card">
            <p className="text-sm text-gray-500">Account Status</p>
            <p className="text-2xl font-semibold mt-1 text-green-600">Active</p>
          </div>
          <div className="card">
            <p className="text-sm text-gray-500">Member Since</p>
            <p className="text-2xl font-semibold mt-1">
              {user?.createdAt
                ? new Date(user.createdAt).toLocaleDateString()
                : '—'}
            </p>
          </div>
        </div>

        {/* Quick actions */}
        <div className="card">
          <h2 className="text-lg font-semibold mb-4">Quick Actions</h2>
          <div className="flex flex-wrap gap-3">
            <Link to="/profile" className="btn-primary">
              Edit Profile
            </Link>
          </div>
        </div>
      </main>
    </>
  );
}
