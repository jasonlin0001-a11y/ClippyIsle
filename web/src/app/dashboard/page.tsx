'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { fetchAllPosts, Post } from '@/lib/posts';
import PostList from '@/components/PostList';
import { Loader2, LogOut, ShieldCheck, RefreshCw, FileText, Plus, User } from 'lucide-react';

export default function Dashboard() {
  const { user, isAdmin, loading, signOut } = useAuth();
  const router = useRouter();
  
  const [posts, setPosts] = useState<Post[]>([]);
  const [postsLoading, setPostsLoading] = useState(true);
  const [postsError, setPostsError] = useState<string | null>(null);

  // loadPosts depends on user.uid
  const loadPosts = useCallback(async () => {
    if (!user) return;

    setPostsLoading(true);
    setPostsError(null);
    try {
      const fetchedPosts = await fetchAllPosts(user.uid);
      setPosts(fetchedPosts);
    } catch (error) {
      console.error('Failed to fetch posts:', error);
      setPostsError('Failed to load posts. Please try again.');
    } finally {
      setPostsLoading(false);
    }
  }, [user]);

  // Redirect logic
  useEffect(() => {
    if (!loading && !user) {
      router.push('/login');
    }
  }, [user, loading, router]);

  // Load posts when user is available
  useEffect(() => {
    if (user) {
      loadPosts();
    }
  }, [user, loadPosts]);

  const handleSignOut = async () => {
    try {
      await signOut();
      router.push('/login');
    } catch (error) {
      console.error('Failed to sign out:', error);
    }
  };

  const handlePostDeleted = (postId: string) => {
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

  // Dashboard UI
  return (
    <div className="min-h-screen bg-[#0a0a0a] p-4 md:p-8">
      <div className="max-w-[800px] mx-auto">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div className="flex items-center gap-4">
            <div className={`flex h-12 w-12 items-center justify-center rounded-full border ${
              isAdmin 
                ? 'bg-gradient-to-br from-teal-500/20 to-blue-600/20 border-teal-500/30' 
                : 'bg-[#2a2a2a] border-[#3a3a3a]'
            }`}>
              {isAdmin ? (
                <ShieldCheck className="h-6 w-6 text-teal-400" />
              ) : (
                <User className="h-6 w-6 text-teal-400" />
              )}
            </div>
            <div>
              <h1 className="text-xl font-bold text-[#fafafa]">
                {isAdmin ? 'CC Island Admin' : 'Creator Dashboard'}
              </h1>
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
              <h2 className="text-lg font-semibold text-[#fafafa]">
                {isAdmin ? 'All Posts' : 'My Posts'}
              </h2>
              <span className="text-sm text-[#fafafa]/60">
                ({posts.length})
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
