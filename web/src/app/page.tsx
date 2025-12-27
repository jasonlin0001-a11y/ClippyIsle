'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { Loader2, LogOut, ShieldAlert, ShieldCheck } from 'lucide-react';

export default function Home() {
  const { user, isAdmin, loading, signOut } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login');
    }
  }, [user, loading, router]);

  const handleSignOut = async () => {
    try {
      await signOut();
      router.push('/login');
    } catch (error) {
      console.error('Failed to sign out:', error);
    }
  };

  // Loading state
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
          <p className="text-[#fafafa]/60">Loading...</p>
        </div>
      </div>
    );
  }

  // Not logged in - will redirect
  if (!user) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
          <p className="text-[#fafafa]/60">Redirecting to login...</p>
        </div>
      </div>
    );
  }

  // Logged in but not admin - Access Denied
  if (!isAdmin) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
        <div className="max-w-md text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-red-500/10 border border-red-500/20">
            <ShieldAlert className="h-10 w-10 text-red-400" />
          </div>
          <h1 className="text-2xl font-bold text-[#fafafa] mb-3">Access Denied</h1>
          <p className="text-[#fafafa]/60 mb-6">
            You do not have administrator privileges. Only authorized admins can access this portal.
          </p>
          <p className="text-sm text-[#fafafa]/40 mb-6">
            Signed in as: {user.email}
          </p>
          <button
            onClick={handleSignOut}
            className="inline-flex items-center gap-2 rounded-lg bg-[#1a1a1a] px-6 py-3 text-[#fafafa] hover:bg-[#2a2a2a] border border-[#2a2a2a] transition-colors"
          >
            <LogOut className="h-5 w-5" />
            Sign Out
          </button>
        </div>
      </div>
    );
  }

  // Admin Dashboard
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
      <div className="max-w-md w-full">
        {/* Welcome Card */}
        <div className="rounded-xl bg-[#1a1a1a] p-8 shadow-xl border border-[#2a2a2a]">
          <div className="flex flex-col items-center text-center">
            <div className="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-gradient-to-br from-teal-500/20 to-blue-600/20 border border-teal-500/30">
              <ShieldCheck className="h-10 w-10 text-teal-400" />
            </div>
            
            <h1 className="text-2xl font-bold text-[#fafafa] mb-2">Welcome, Admin</h1>
            <p className="text-[#fafafa]/60 mb-1">You have full access to the portal.</p>
            <p className="text-sm text-teal-400 mb-8">{user.email}</p>

            {/* Dashboard Placeholder */}
            <div className="w-full rounded-lg bg-[#0a0a0a] border border-[#2a2a2a] p-6 mb-6">
              <p className="text-[#fafafa]/40 text-sm">
                Dashboard features coming soon...
              </p>
            </div>

            <button
              onClick={handleSignOut}
              className="inline-flex items-center gap-2 rounded-lg bg-red-500/10 px-6 py-3 text-red-400 hover:bg-red-500/20 border border-red-500/20 transition-colors"
            >
              <LogOut className="h-5 w-5" />
              Sign Out
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
