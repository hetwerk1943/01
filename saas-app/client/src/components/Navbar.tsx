/**
 * Navbar component – top navigation with user info and logout.
 */
import { Link, useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

export function Navbar() {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <nav className="bg-white shadow-sm border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center">
          <div className="flex items-center gap-6">
            <Link to="/dashboard" className="text-xl font-bold text-primary-600">
              SaaS App
            </Link>
            <Link
              to="/dashboard"
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              Dashboard
            </Link>
            <Link
              to="/profile"
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              Profile
            </Link>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-500">{user?.email}</span>
            <button onClick={handleLogout} className="btn-secondary text-sm py-1.5">
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}
