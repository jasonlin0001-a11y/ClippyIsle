'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { fetchAllPosts } from '@/lib/posts';
import { Post } from '@/types';
import PostList from '@/components/PostList';
import { Loader2, LogOut, ShieldAlert, ShieldCheck, RefreshCw, FileText, Plus } from 'lucide-react';

export default function Home() {
  const { user, isAdmin, loading, signOut } = useAuth();
  const router = useRouter();
  
  const [posts, setPosts] = useState<Post[]>([]);
  const [postsLoading, setPostsLoading] = useState(true);
  const [postsError, setPostsError] = useState<string | null>(null);

  const loadPosts = useCallback(async () => {
    setPostsLoading(true);
    setPostsError(null);
    try {
      const fetchedPosts = await fetchAllPosts();
      setPosts(fetchedPosts);
    } catch (error) {
      console.error('Failed to fetch posts:', error);
      setPostsError('Failed to load posts. Please try again.');
    } finally {
      setPostsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login');
    }
  }, [user, loading, router]);

  useEffect(() => {
    if (isAdmin) {
      loadPosts();
    }
  }, [isAdmin, loadPosts]);

  const handleSignOut = async () => {
    try {
      await signOut();
      router.push('/login');
    } catch (error) {
      console.error('Failed to sign out:', error);
    }
  };

  const handlePostDeleted = (postId: string) => {
    // Optimistically remove the post from UI
    setPosts((prevPosts) => prevPosts.filter((post) => post.id !== postId));
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
    <div className="min-h-screen bg-[#0a0a0a] p-4 md:p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-teal-500/20 to-blue-600/20 border border-teal-500/30">
              <ShieldCheck className="h-6 w-6 text-teal-400" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-[#fafafa]">CC ISLE Admin</h1>
              <p className="text-sm text-[#fafafa]/60">{user.email}</p>
            </div>
          </div>
          
          <button
            onClick={handleSignOut}
            className="inline-flex items-center gap-2 rounded-lg bg-red-500/10 px-4 py-2 text-sm text-red-400 hover:bg-red-500/20 border border-red-500/20 transition-colors"
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </div>

        {/* Posts Section */}
        <div className="rounded-xl bg-[#1a1a1a] border border-[#2a2a2a] overflow-hidden">
          {/* Section Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-[#2a2a2a]">
            <div className="flex items-center gap-3">
              <FileText className="h-5 w-5 text-teal-400" />
              <h2 className="text-lg font-semibold text-[#fafafa]">Posts</h2>
              <span className="text-sm text-[#fafafa]/60">
                ({posts.length} total)
              </span>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => router.push('/create')}
                className="inline-flex items-center gap-2 rounded-lg bg-teal-500 px-4 py-2 text-sm text-white hover:bg-teal-600 transition-colors"
              >
                <Plus className="h-4 w-4" />
                New Post
              </button>
              <button
                onClick={loadPosts}
                disabled={postsLoading}
                className="inline-flex items-center gap-2 rounded-lg bg-[#2a2a2a] px-4 py-2 text-sm text-[#fafafa] hover:bg-[#3a3a3a] transition-colors disabled:opacity-50"
              >
                <RefreshCw className={`h-4 w-4 ${postsLoading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
            </div>
          </div>

          {/* Content */}
          <div className="p-4">
            {postsLoading ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin text-teal-500" />
              </div>
            ) : postsError ? (
              <div className="text-center py-12">
                <p className="text-red-400 mb-4">{postsError}</p>
                <button
                  onClick={loadPosts}
                  className="text-teal-400 hover:text-teal-300 text-sm"
                >
                  Try again
                </button>
              </div>
            ) : (
              <PostList posts={posts} onPostDeleted={handlePostDeleted} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
