/**
 * Profile page – view and edit user profile, change password, delete account.
 */
import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useNavigate } from 'react-router-dom';
import { usersApi } from '../api';
import { useAuthStore } from '../store/authStore';
import { Navbar } from '../components/Navbar';
import type { User } from '../types';

const profileSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  bio: z.string().max(500).optional(),
  avatarUrl: z.string().url('Must be a valid URL').optional().or(z.literal('')),
});

const passwordSchema = z.object({
  currentPassword: z.string().min(1, 'Required'),
  newPassword: z
    .string()
    .min(8, 'At least 8 characters')
    .regex(/[A-Z]/, 'Must include an uppercase letter')
    .regex(/[0-9]/, 'Must include a number'),
});

type ProfileData = z.infer<typeof profileSchema>;
type PasswordData = z.infer<typeof passwordSchema>;

export function ProfilePage() {
  const navigate = useNavigate();
  const logout = useAuthStore((s) => s.logout);
  const [user, setUser] = useState<User | null>(null);
  const [profileMsg, setProfileMsg] = useState('');
  const [passwordMsg, setPasswordMsg] = useState('');
  const [profileError, setProfileError] = useState('');
  const [passwordError, setPasswordError] = useState('');

  const profileForm = useForm<ProfileData>({
    resolver: zodResolver(profileSchema),
  });

  const passwordForm = useForm<PasswordData>({
    resolver: zodResolver(passwordSchema),
  });

  // Load user profile on mount
  useEffect(() => {
    usersApi.getProfile().then((res) => {
      const u: User = res.data.user;
      setUser(u);
      profileForm.reset({
        name: u.name,
        bio: u.bio ?? '',
        avatarUrl: u.avatarUrl ?? '',
      });
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const onUpdateProfile = async (data: ProfileData) => {
    try {
      setProfileError('');
      const res = await usersApi.updateProfile(data);
      setUser((prev) => ({ ...prev!, ...res.data.user }));
      setProfileMsg('Profile updated successfully!');
      setTimeout(() => setProfileMsg(''), 3000);
    } catch (err: unknown) {
      setProfileError(
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Update failed'
      );
    }
  };

  const onChangePassword = async (data: PasswordData) => {
    try {
      setPasswordError('');
      await usersApi.changePassword(data);
      setPasswordMsg('Password changed successfully!');
      passwordForm.reset();
      setTimeout(() => setPasswordMsg(''), 3000);
    } catch (err: unknown) {
      setPasswordError(
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Password change failed'
      );
    }
  };

  const onDeleteAccount = async () => {
    if (!confirm('Are you sure you want to delete your account? This cannot be undone.')) return;
    try {
      await usersApi.deleteAccount();
      logout();
      navigate('/login');
    } catch {
      alert('Failed to delete account.');
    }
  };

  return (
    <>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        <h1 className="text-3xl font-bold text-gray-900">My Profile</h1>

        {/* Profile details */}
        <div className="card">
          <h2 className="text-lg font-semibold mb-4">Profile Details</h2>

          {profileMsg && (
            <div className="bg-green-50 border border-green-200 text-green-700 rounded-md p-3 mb-4 text-sm">
              {profileMsg}
            </div>
          )}
          {profileError && (
            <div className="bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm">
              {profileError}
            </div>
          )}

          <form
            onSubmit={profileForm.handleSubmit(onUpdateProfile)}
            className="space-y-4"
          >
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Full Name
              </label>
              <input
                type="text"
                {...profileForm.register('name')}
                className="input"
              />
              {profileForm.formState.errors.name && (
                <p className="text-red-500 text-xs mt-1">
                  {profileForm.formState.errors.name.message}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Bio
              </label>
              <textarea
                {...profileForm.register('bio')}
                className="input h-20 resize-none"
                placeholder="Tell us about yourself…"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Avatar URL
              </label>
              <input
                type="url"
                {...profileForm.register('avatarUrl')}
                className="input"
                placeholder="https://example.com/avatar.jpg"
              />
              {profileForm.formState.errors.avatarUrl && (
                <p className="text-red-500 text-xs mt-1">
                  {profileForm.formState.errors.avatarUrl.message}
                </p>
              )}
            </div>

            <div className="pt-2">
              <p className="text-sm text-gray-500 mb-3">
                Email: <span className="font-medium">{user?.email}</span> (cannot be changed)
              </p>
              <button
                type="submit"
                disabled={profileForm.formState.isSubmitting}
                className="btn-primary"
              >
                {profileForm.formState.isSubmitting ? 'Saving…' : 'Save Changes'}
              </button>
            </div>
          </form>
        </div>

        {/* Change password */}
        <div className="card">
          <h2 className="text-lg font-semibold mb-4">Change Password</h2>

          {passwordMsg && (
            <div className="bg-green-50 border border-green-200 text-green-700 rounded-md p-3 mb-4 text-sm">
              {passwordMsg}
            </div>
          )}
          {passwordError && (
            <div className="bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm">
              {passwordError}
            </div>
          )}

          <form
            onSubmit={passwordForm.handleSubmit(onChangePassword)}
            className="space-y-4"
          >
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Current Password
              </label>
              <input
                type="password"
                {...passwordForm.register('currentPassword')}
                className="input"
              />
              {passwordForm.formState.errors.currentPassword && (
                <p className="text-red-500 text-xs mt-1">
                  {passwordForm.formState.errors.currentPassword.message}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                New Password
              </label>
              <input
                type="password"
                {...passwordForm.register('newPassword')}
                className="input"
              />
              {passwordForm.formState.errors.newPassword && (
                <p className="text-red-500 text-xs mt-1">
                  {passwordForm.formState.errors.newPassword.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={passwordForm.formState.isSubmitting}
              className="btn-primary"
            >
              {passwordForm.formState.isSubmitting ? 'Updating…' : 'Update Password'}
            </button>
          </form>
        </div>

        {/* Danger zone */}
        <div className="card border-red-200">
          <h2 className="text-lg font-semibold text-red-600 mb-2">Danger Zone</h2>
          <p className="text-sm text-gray-500 mb-4">
            Permanently delete your account and all associated data.
          </p>
          <button
            onClick={onDeleteAccount}
            className="inline-flex items-center px-4 py-2 bg-red-600 text-white font-medium rounded-md hover:bg-red-700 transition-colors"
          >
            Delete Account
          </button>
        </div>
      </main>
    </>
  );
}
