'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { doc, getDoc, Timestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { Loader2, AlertTriangle, Link as LinkIcon, Package, User, ExternalLink } from 'lucide-react';

interface ShareMetadata {
  hasPassword: boolean;
  sharerNickname?: string;
  itemCount: number;
}

interface ClipboardItem {
  id: string;
  content: string;
  type: string;
  timestamp: Timestamp;
  isPinned: boolean;
  isTrashed: boolean;
  filename?: string;
  displayName?: string;
  tags?: string[];
}

interface ShareData {
  items: ClipboardItem[];
  createdAt: Timestamp;
  itemCount: number;
  sharerUID?: string;
  sharerNickname?: string;
  passwordHash?: string;
}

function ShareReceiverContent() {
  const searchParams = useSearchParams();
  const id = searchParams.get('id');
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [metadata, setMetadata] = useState<ShareMetadata | null>(null);

  useEffect(() => {
    async function fetchShareMetadata() {
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
        const shareRef = doc(db, 'sharedClipboards', id);
        const shareSnap = await getDoc(shareRef);

        if (shareSnap.exists()) {
          const data = shareSnap.data() as ShareData;
          setMetadata({
            hasPassword: !!data.passwordHash,
            sharerNickname: data.sharerNickname,
            itemCount: data.itemCount || data.items?.length || 0,
          });
          
          // Try to open the iOS app after a short delay to let user see the page
          setTimeout(() => {
            window.location.href = `ccisle://import?id=${id}`;
          }, 500);
        } else {
          setError('Share not found');
        }
      } catch (err) {
        console.error('Error fetching share:', err);
        setError('Failed to load share');
      } finally {
        setLoading(false);
      }
    }

    fetchShareMetadata();
  }, [id]);

  // No ID provided - show error
  if (!id) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
        <div className="max-w-md text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-yellow-500/10 border border-yellow-500/20">
            <AlertTriangle className="h-10 w-10 text-yellow-400" />
          </div>
          <h1 className="text-2xl font-bold text-[#fafafa] mb-3">連結無效</h1>
          <p className="text-[#fafafa]/60 mb-6">
            缺少分享 ID。請使用有效的分享連結。
          </p>
          <div className="flex items-center justify-center gap-2 text-sm text-[#fafafa]/40">
            <LinkIcon className="h-4 w-4" />
            <span>Expected format: /share?id=SHARE_ID</span>
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
          <p className="text-[#fafafa]/60">正在載入分享內容...</p>
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
          <h1 className="text-2xl font-bold text-[#fafafa] mb-3">找不到分享</h1>
          <p className="text-[#fafafa]/60 mb-6">{error}</p>
        </div>
      </div>
    );
  }

  // Share found - show info and prompt to open app
  if (metadata) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
        <div className="max-w-md w-full">
          {/* Header */}
          <div className="text-center mb-6">
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-teal-500/10 border border-teal-500/20">
              <Package className="h-8 w-8 text-teal-400" />
            </div>
            <h1 className="text-2xl font-bold text-[#fafafa] mb-2">CC ISLE 剪貼簿分享</h1>
            <p className="text-[#fafafa]/60">正在嘗試開啟 App...</p>
          </div>
          
          {/* Share Info Card */}
          <div className="rounded-xl bg-[#1a1a1a] border border-[#2a2a2a] overflow-hidden mb-6">
            <div className="p-4 space-y-3">
              {metadata.sharerNickname && (
                <div className="flex items-center gap-3 text-sm">
                  <User className="h-4 w-4 text-[#fafafa]/40" />
                  <span className="text-[#fafafa]/60">分享者：</span>
                  <span className="text-[#fafafa]">{metadata.sharerNickname}</span>
                </div>
              )}
              
              <div className="flex items-center gap-3 text-sm">
                <Package className="h-4 w-4 text-[#fafafa]/40" />
                <span className="text-[#fafafa]/60">項目數量：</span>
                <span className="text-[#fafafa]">{metadata.itemCount} 個項目</span>
              </div>
              
              {metadata.hasPassword && (
                <div className="mt-3 px-3 py-2 rounded-lg bg-yellow-500/10 border border-yellow-500/20">
                  <p className="text-sm text-yellow-400">🔐 此分享需要密碼才能匯入</p>
                </div>
              )}
            </div>
          </div>
          
          {/* Open App Button */}
          <a
            href={`ccisle://import?id=${id}`}
            className="block w-full py-3 px-4 bg-teal-500 hover:bg-teal-600 text-white text-center font-medium rounded-xl transition-colors"
          >
            開啟 CC ISLE App
          </a>
          
          <p className="mt-4 text-center text-sm text-[#fafafa]/40">
            如果沒有自動跳轉，請點擊上方按鈕
          </p>
          
          {/* App Store Link */}
          <div className="mt-6 text-center">
            <p className="text-sm text-[#fafafa]/40 mb-2">還沒有 CC ISLE?</p>
            <a
              href="https://apps.apple.com/app/cc-isle"
              className="inline-flex items-center gap-2 text-sm text-teal-400 hover:text-teal-300"
            >
              <ExternalLink className="h-4 w-4" />
              在 App Store 下載
            </a>
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
        <p className="text-[#fafafa]/60">載入中...</p>
      </div>
    </div>
  );
}

export default function ShareReceiver() {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <ShareReceiverContent />
    </Suspense>
  );
}
