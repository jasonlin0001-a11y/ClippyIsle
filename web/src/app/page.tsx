'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
<<<<<<< HEAD
import { Loader2 } from 'lucide-react';

function RedirectContent() {
  const searchParams = useSearchParams();
  const id = searchParams.get('id'); 
  const [status, setStatus] = useState<'loading' | 'error' | 'found'>('loading');

  useEffect(() => {
    if (!id) {
      setStatus('error'); 
      return;
    }

    async function checkPost() {
      // 🛑 關鍵修正：檢查資料庫是否連接成功
      // 這行代碼會讓 TypeScript 知道 "如果 db 是空的，就直接停止"，
      // 所以下面的 db 必定是安全的。
      if (!db) {
        console.error("Firebase DB not initialized");
        setStatus('error');
        return;
      }

      try {
        const docRef = doc(db, 'creator_posts', id!);
        const docSnap = await getDoc(docRef);

        if (docSnap.exists()) {
          setStatus('found');
        } else {
          setStatus('error');
        }
      } catch (e) {
        console.error(e);
        setStatus('error');
      }
    }

    checkPost();
  }, [id]);

  if (status === 'loading') {
    return (
      <div className="flex flex-col items-center gap-4">
        <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
        <p className="text-[#fafafa]/60">正在尋找您的島嶼...</p>
=======
import { Loader2, AlertTriangle, ExternalLink, Link as LinkIcon } from 'lucide-react';
import Image from 'next/image';

interface PostData {
  content_url?: string;
  link_title?: string;
  link_description?: string;
  link_image?: string;
  curator_note?: string;
}

function SharingReceiverContent() {
  const searchParams = useSearchParams();
  const id = searchParams.get('id');
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [postData, setPostData] = useState<PostData | null>(null);

  useEffect(() => {
    async function fetchPost() {
      if (!id) {
        setLoading(false);
        return;
      }

      if (!db) {
        setError('Firebase is not initialized');
        setLoading(false);
        return;
      }

      try {
        const postRef = doc(db, 'creator_posts', id);
        const postSnap = await getDoc(postRef);

        if (postSnap.exists()) {
          const data = postSnap.data() as PostData;
          setPostData(data);
          
          // Redirect to content URL if available
          if (data.content_url) {
            window.location.href = data.content_url;
          }
        } else {
          setError('Post not found');
        }
      } catch (err) {
        console.error('Error fetching post:', err);
        setError('Failed to load post');
      } finally {
        setLoading(false);
      }
    }

    fetchPost();
  }, [id]);

  // No ID provided - show error
  if (!id) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
        <div className="max-w-md text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-yellow-500/10 border border-yellow-500/20">
            <AlertTriangle className="h-10 w-10 text-yellow-400" />
          </div>
          <h1 className="text-2xl font-bold text-[#fafafa] mb-3">Link Invalid</h1>
          <p className="text-[#fafafa]/60 mb-6">
            Missing ID parameter. Please use a valid sharing link.
          </p>
          <div className="flex items-center justify-center gap-2 text-sm text-[#fafafa]/40">
            <LinkIcon className="h-4 w-4" />
            <span>Expected format: /?id=POST_ID</span>
          </div>
        </div>
      </div>
    );
  }

  // Loading state
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
          <p className="text-[#fafafa]/60">Loading shared content...</p>
        </div>
>>>>>>> copilot/create-firebase-function-scrape-metadata
      </div>
    );
  }

<<<<<<< HEAD
  if (status === 'found') {
    return (
      <div className="text-center p-8 bg-[#1a1a1a] rounded-xl border border-[#2a2a2a] max-w-md shadow-2xl">
        <h1 className="text-2xl font-bold text-[#fafafa] mb-4">找到了！</h1>
        <p className="text-[#fafafa]/60 mb-6">這篇文章存在，正在嘗試開啟 App...</p>
        <button className="px-6 py-3 bg-teal-600 hover:bg-teal-500 text-white rounded-lg font-medium transition-colors shadow-lg shadow-teal-900/20">
          開啟 CC ISLE App
        </button>
=======
  // Error state
  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
        <div className="max-w-md text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-red-500/10 border border-red-500/20">
            <AlertTriangle className="h-10 w-10 text-red-400" />
          </div>
          <h1 className="text-2xl font-bold text-[#fafafa] mb-3">Error</h1>
          <p className="text-[#fafafa]/60 mb-6">{error}</p>
        </div>
>>>>>>> copilot/create-firebase-function-scrape-metadata
      </div>
    );
  }

<<<<<<< HEAD
  return (
    <div className="text-center p-8 bg-[#1a1a1a] rounded-xl border border-[#2a2a2a] max-w-md shadow-2xl">
      <h1 className="text-2xl font-bold text-[#fafafa] mb-2">連結無效</h1>
      <p className="text-[#fafafa]/60 mb-6">缺少 ID 或文章不存在。</p>
      <div className="h-px w-full bg-[#2a2a2a] mb-6"></div>
      <p className="text-sm text-[#fafafa]/40 mb-4">如果您是管理者：</p>
      <a 
        href="/dashboard"
        className="px-6 py-3 bg-[#2a2a2a] hover:bg-[#333] text-white rounded-lg font-medium transition-colors inline-block border border-[#333]"
      >
        前往管理後台
      </a>
=======
  // Post found but redirecting - show preview while redirecting
  if (postData) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
        <div className="max-w-md text-center">
          <div className="flex flex-col items-center gap-4 mb-6">
            <Loader2 className="h-8 w-8 animate-spin text-teal-500" />
            <p className="text-[#fafafa]/60">Redirecting to content...</p>
          </div>
          
          {/* Preview Card */}
          <div className="rounded-xl bg-[#1a1a1a] border border-[#2a2a2a] overflow-hidden text-left">
            {postData.link_image && (
              <div className="relative aspect-video bg-[#2a2a2a]">
                <Image 
                  src={postData.link_image} 
                  alt={postData.link_title || 'Preview'} 
                  fill
                  className="object-cover"
                  unoptimized
                />
              </div>
            )}
            <div className="p-4">
              {postData.link_title && (
                <h2 className="text-lg font-semibold text-[#fafafa] mb-2">
                  {postData.link_title}
                </h2>
              )}
              {postData.link_description && (
                <p className="text-sm text-[#fafafa]/60 mb-3">
                  {postData.link_description}
                </p>
              )}
              {postData.curator_note && (
                <p className="text-sm text-teal-400 italic">
                  &quot;{postData.curator_note}&quot;
                </p>
              )}
              {postData.content_url && (
                <a
                  href={postData.content_url}
                  className="inline-flex items-center gap-2 mt-4 text-sm text-teal-400 hover:text-teal-300"
                >
                  <ExternalLink className="h-4 w-4" />
                  Open link manually
                </a>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

// Loading fallback for Suspense
function LoadingFallback() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
      <div className="flex flex-col items-center gap-4">
        <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
        <p className="text-[#fafafa]/60">Loading...</p>
      </div>
>>>>>>> copilot/create-firebase-function-scrape-metadata
    </div>
  );
}

<<<<<<< HEAD
export default function Home() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
      <Suspense fallback={<div className="text-white">Loading...</div>}>
        <RedirectContent />
      </Suspense>
    </div>
  );
}
=======
export default function SharingReceiver() {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <SharingReceiverContent />
    </Suspense>
  );
}
>>>>>>> copilot/create-firebase-function-scrape-metadata
