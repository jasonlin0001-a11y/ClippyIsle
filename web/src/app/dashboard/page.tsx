'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
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
    } catch (error) {
      console.error('Failed to sign out:', error);
    }
  };

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
            </div>
          </div>
          
          <button
            onClick={handleSignOut}
            className="inline-flex items-center gap-2 rounded-lg bg-[#1a1a1a] px-4 py-2 text-sm text-[#fafafa]/60 hover:text-red-400 hover:bg-red-500/10 border border-[#2a2a2a] transition-colors"
          >
            <LogOut className="h-4 w-4" />
            Sign Out
          </button>
        </div>

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
              >
                <RefreshCw className={`h-4 w-4 ${postsLoading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
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

      </div>
    </div>
  );
}