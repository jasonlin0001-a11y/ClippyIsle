'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
<<<<<<< HEAD
import { getAuth, onAuthStateChanged, User, signOut } from 'firebase/auth';
import { app } from '@/lib/firebase';
import { fetchAllPosts, deletePost, Post } from '@/lib/posts';
import { Loader2, LogOut, ShieldCheck, RefreshCw, Plus, Trash2, ExternalLink } from 'lucide-react';

export default function DashboardPage() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true); // 身分驗證載入中
  const [posts, setPosts] = useState<Post[]>([]);
  const [postsLoading, setPostsLoading] = useState(false);
  
  const router = useRouter();
  const auth = getAuth(app);

  // 1. 抓取文章列表
  const loadPosts = useCallback(async () => {
    setPostsLoading(true);
    try {
      const data = await fetchAllPosts();
      setPosts(data);
    } catch (error) {
      console.error("Failed to load posts", error);
      // 如果是因為權限不足(例如不是管理員)，這裡可以顯示錯誤
    } finally {
      setPostsLoading(false);
    }
  }, []);

  // 2. 檢查登入狀態 (守門員)
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      if (!currentUser) {
        router.push('/login'); 
      } else {
        setUser(currentUser);
        loadPosts(); // 有登入 -> 抓文章
      }
      setLoading(false);
    });
    return () => unsubscribe();
  }, [auth, router, loadPosts]);

  // 3. 登出
  const handleSignOut = async () => {
    try {
      await signOut(auth);
      router.push('/');
=======
import { useAuth } from '@/context/AuthContext';
import { fetchAllPosts } from '@/lib/posts';
import { Post } from '@/types';
import PostList from '@/components/PostList';
import { Loader2, LogOut, ShieldCheck, RefreshCw, FileText, Plus, User } from 'lucide-react';

export default function Dashboard() {
  const { user, isAdmin, loading, signOut } = useAuth(); // isAdmin 這裡僅用於 UI 顯示，資料權限由後端 posts.ts 再次確認
  const router = useRouter();
  
  const [posts, setPosts] = useState<Post[]>([]);
  const [postsLoading, setPostsLoading] = useState(true);
  const [postsError, setPostsError] = useState<string | null>(null);

  // 修正：loadPosts 依賴 user.uid
  const loadPosts = useCallback(async () => {
    if (!user) return; // 沒登入不動作

    setPostsLoading(true);
    setPostsError(null);
    try {
      // ✅ 關鍵修改：將 UID 傳進去，讓後端判斷要回傳什麼資料
      const fetchedPosts = await fetchAllPosts(user.uid);
      setPosts(fetchedPosts);
    } catch (error) {
      console.error('Failed to fetch posts:', error);
      setPostsError('Failed to load posts. Please try again.');
    } finally {
      setPostsLoading(false);
    }
  }, [user]);

  // 導向邏輯
  useEffect(() => {
    if (!loading && !user) {
      router.push('/login');
    }
  }, [user, loading, router]);

  // 修正：只要有使用者登入就載入資料 (不再只限制 isAdmin)
  useEffect(() => {
    if (user) {
      loadPosts();
    }
  }, [user, loadPosts]);

  const handleSignOut = async () => {
    try {
      await signOut();
      router.push('/login');
>>>>>>> copilot/create-firebase-function-scrape-metadata
    } catch (error) {
      console.error('Failed to sign out:', error);
    }
  };

<<<<<<< HEAD
  // 4. 刪除文章
  async function handleDelete(postId: string) {
    if (!confirm('確定要刪除這篇文章嗎？此動作無法復原。')) return;
    try {
      await deletePost(postId);
      setPosts(posts.filter(p => p.id !== postId)); // 即時更新畫面
    } catch (error) {
      alert('刪除失敗 (可能是權限不足)');
    }
  }

  // --- 載入畫面 ---
=======
  const handlePostDeleted = (postId: string) => {
    setPosts((prevPosts) => prevPosts.filter((post) => post.id !== postId));
  };

  // Loading state
>>>>>>> copilot/create-firebase-function-scrape-metadata
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

<<<<<<< HEAD
  if (!user) return null;

  // --- 正式儀表板 ---
  return (
    <div className="min-h-screen bg-[#0a0a0a] p-4 md:p-8">
      {/* 限制最大寬度為 800px，保持置中 */}
      <div className="mx-auto max-w-[800px]">
        
        {/* Header 區域 */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div className="flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-teal-500/10 border border-teal-500/20">
              <ShieldCheck className="h-6 w-6 text-teal-400" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-[#fafafa]">CC Island Dashboard</h1>
              <p className="text-sm text-[#fafafa]/40">{user.email}</p>
=======
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

  // 移除：Access Denied 區塊已刪除，因為現在一般創作者也可以進來了

  // Dashboard UI
  return (
    <div className="min-h-screen bg-[#0a0a0a] p-4 md:p-8">
      <div className="max-w-[800px] mx-auto">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div className="flex items-center gap-4">
            {/* 根據身分顯示不同圖示與標題 */}
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
>>>>>>> copilot/create-firebase-function-scrape-metadata
            </div>
          </div>
          
          <button
            onClick={handleSignOut}
<<<<<<< HEAD
            className="inline-flex items-center gap-2 rounded-lg bg-[#1a1a1a] px-4 py-2 text-sm text-[#fafafa]/60 hover:text-red-400 hover:bg-red-500/10 border border-[#2a2a2a] transition-colors"
=======
            className="inline-flex items-center gap-2 rounded-lg bg-red-500/10 px-4 py-2 text-sm text-red-400 hover:bg-red-500/20 border border-red-500/20 transition-colors"
>>>>>>> copilot/create-firebase-function-scrape-metadata
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </div>

<<<<<<< HEAD
        {/* 控制列 (New Post / Refresh) */}
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-[#fafafa]">
            Posts <span className="text-[#fafafa]/40 text-sm ml-2">{posts.length} total</span>
          </h2>
          <div className="flex gap-3">
             <button
                onClick={loadPosts}
                disabled={postsLoading}
                className="inline-flex items-center gap-2 rounded-lg bg-[#1a1a1a] px-4 py-2 text-sm text-[#fafafa] hover:bg-[#2a2a2a] border border-[#2a2a2a] transition-colors disabled:opacity-50"
=======
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
>>>>>>> copilot/create-firebase-function-scrape-metadata
              >
                <RefreshCw className={`h-4 w-4 ${postsLoading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
<<<<<<< HEAD
              <a
                href="/create"
                className="inline-flex items-center gap-2 rounded-lg bg-teal-600 px-4 py-2 text-sm font-medium text-white hover:bg-teal-500 transition-colors shadow-lg shadow-teal-900/20"
              >
                <Plus className="h-4 w-4" />
                New Post
              </a>
          </div>
        </div>

        {/* 文章列表 */}
        <div className="space-y-4">
          {posts.length === 0 && !postsLoading ? (
             <div className="rounded-xl border border-[#2a2a2a] bg-[#1a1a1a] p-12 text-center">
                <p className="text-[#fafafa]/40">No posts found.</p>
             </div>
          ) : (
            posts.map((post) => (
              <div key={post.id} className="group relative flex items-start gap-4 rounded-xl border border-[#2a2a2a] bg-[#1a1a1a] p-4 transition-all hover:border-teal-500/30 hover:shadow-md">
                
                {/* 縮圖 */}
                <div className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-lg bg-[#2a2a2a]">
                  {post.link_image ? (
                    <img src={post.link_image} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-[#fafafa]/20">
                      <ExternalLink className="h-6 w-6" />
                    </div>
                  )}
                </div>
                
                {/* 標題與資訊 */}
                <div className="flex-1 min-w-0 py-1">
                  <h3 className="truncate text-base font-medium text-[#fafafa] mb-1">
                    {post.link_title || post.curator_note || "Untitled Post"}
                  </h3>
                  <p className="line-clamp-1 text-sm text-[#fafafa]/60 mb-2">
                    {post.link_description || post.content_url || "No description"}
                  </p>
                  <div className="flex items-center gap-3 text-xs text-[#fafafa]/40">
                    <span className="rounded bg-[#2a2a2a] px-2 py-0.5">
                      {post.link_domain || "Web Upload"}
                    </span>
                    <span>•</span>
                    <span>
                      {post.created_at?.toDate ? post.created_at.toDate().toLocaleDateString() : 'Just now'}
                    </span>
                  </div>
                </div>

                {/* 刪除按鈕 (Hover 時才比較明顯) */}
                <button 
                  onClick={() => handleDelete(post.id)}
                  className="rounded-lg p-2 text-[#fafafa]/20 hover:bg-red-500/10 hover:text-red-400 transition-colors"
                  title="Delete Post"
                >
                  <Trash2 className="h-5 w-5" />
                </button>
              </div>
            ))
          )}
        </div>

=======
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
>>>>>>> copilot/create-firebase-function-scrape-metadata
      </div>
    </div>
  );
}