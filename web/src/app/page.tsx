'use client';

import { useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
<<<<<<< Updated upstream
import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
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
=======
import { Loader2, Download, ExternalLink } from 'lucide-react';

function RedirectContent() {
  const searchParams = useSearchParams();

  useEffect(() => {
    // 1. 取得網址列的 id 參數 (支援 id 或 contentId)
    const shareId = searchParams.get('id') || searchParams.get('contentId');

    if (shareId) {
      // 2. 構建自定義 Scheme 網址
      const appSchemeUrl = `ccisle://import?id=${shareId}`;
      
      console.log('正在嘗試喚醒 App:', appSchemeUrl);

      // 3. 嘗試自動跳轉到 App
      window.location.href = appSchemeUrl;

      // 設定一個備案：如果 2 秒後還留在網頁，可能沒裝 App，就什麼都不做（讓使用者看下載按鈕）
    }
  }, [searchParams]);

  const handleDownload = () => {
    // 這裡替換為您的 App Store 實際連結
    window.location.href = 'https://apps.apple.com/app/your-app-id'; 
  };

  const shareId = searchParams.get('id') || searchParams.get('contentId');

  return (
    <main className="min-h-screen bg-[#121212] flex flex-col items-center justify-center p-6 text-center">
      <div className="max-w-sm w-full space-y-8">
        {/* Logo 或 圖示 */}
        <div className="flex justify-center">
          <div className="w-20 h-20 bg-teal-600 rounded-3xl flex items-center justify-center shadow-lg shadow-teal-900/20">
            <span className="text-white text-3xl font-bold">CC</span>
>>>>>>> Stashed changes
          </div>
        </div>

        <div className="space-y-4">
          <h1 className="text-2xl font-bold text-white">CC ISLE Shared Content</h1>
          <p className="text-gray-400 leading-relaxed">
            {shareId 
              ? '正在嘗試為您開啟 CC ISLE App...' 
              : '歡迎來到 CC ISLE。請透過分享連結進入此頁面。'}
          </p>
        </div>

<<<<<<< Updated upstream
  // Loading state
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
          <p className="text-[#fafafa]/60">Loading shared content...</p>
        </div>
      </div>
    );
  }

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
      </div>
    );
  }

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
=======
        {shareId && (
          <div className="flex flex-col gap-4 pt-4">
            <div className="flex items-center justify-center gap-2 text-teal-500 animate-pulse text-sm">
              <Loader2 className="animate-spin" size={16} />
              正在跳轉至 App
>>>>>>> Stashed changes
            </div>
            
            <button
              onClick={() => window.location.href = `ccisle://import?id=${shareId}`}
              className="w-full bg-[#2a2a2a] hover:bg-[#333] text-white font-medium py-3 rounded-xl border border-[#444] transition-all flex items-center justify-center gap-2"
            >
              沒有跳轉？點擊手動開啟 <ExternalLink size={18} />
            </button>
          </div>
        )}

        <div className="pt-8 border-t border-[#333]">
          <p className="text-sm text-gray-500 mb-4">尚未安裝 CC ISLE？</p>
          <button
            onClick={handleDownload}
            className="w-full bg-teal-600 hover:bg-teal-500 text-white font-bold py-4 rounded-2xl transition-all shadow-lg flex items-center justify-center gap-2"
          >
            <Download size={20} /> 下載 CC ISLE App
          </button>
        </div>
        
        {/* 如果管理員想登入後台，提供一個隱藏小連結 */}
        <div className="pt-12">
          <a href="/dashboard" className="text-gray-600 hover:text-gray-400 text-xs transition-colors">
            Admin Dashboard
          </a>
        </div>
      </div>
<<<<<<< Updated upstream
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
    </div>
  );
}

export default function SharingReceiver() {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <SharingReceiverContent />
    </Suspense>
  );
}
=======
    </main>
  );
}

export default function Home() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-[#121212]" />}>
      <RedirectContent />
    </Suspense>
  );
}
>>>>>>> Stashed changes
