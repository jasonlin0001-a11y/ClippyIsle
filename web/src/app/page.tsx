'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { Loader2 } from 'lucide-react';

// 這是內層組件，專門處理 ?id=xxx
function RedirectContent() {
  const searchParams = useSearchParams();
  const id = searchParams.get('id'); // 抓取網址上的 ?id=...
  const [status, setStatus] = useState<'loading' | 'error' | 'found'>('loading');

  useEffect(() => {
    if (!id) {
      setStatus('error'); // 沒 ID，顯示錯誤
      return;
    }

    async function checkPost() {
      try {
        // 嘗試去資料庫找這篇文章
        const docRef = doc(db, 'creator_posts', id!);
        const docSnap = await getDoc(docRef);

        if (docSnap.exists()) {
          // 找到了！執行轉址邏輯 (這裡先暫時顯示成功，之後可接 Deep Link)
          // window.location.href = `clippyisle://post/${id}`;
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
      </div>
    );
  }

  if (status === 'found') {
    return (
      <div className="text-center p-8 bg-[#1a1a1a] rounded-xl border border-[#2a2a2a] max-w-md">
        <h1 className="text-2xl font-bold text-[#fafafa] mb-4">找到了！</h1>
        <p className="text-[#fafafa]/60 mb-6">這篇文章存在，正在嘗試開啟 App...</p>
        <button className="px-6 py-3 bg-teal-600 hover:bg-teal-500 text-white rounded-lg font-medium transition-colors">
          開啟 CC ISLE App
        </button>
      </div>
    );
  }

  // status === 'error'
  return (
    <div className="text-center p-8 bg-[#1a1a1a] rounded-xl border border-[#2a2a2a] max-w-md">
      <h1 className="text-2xl font-bold text-[#fafafa] mb-2">連結無效 (缺少 ID)</h1>
      <p className="text-[#fafafa]/60 mb-6">如果沒有自動跳轉，請點擊下方按鈕：</p>
      <a 
        href="/dashboard"
        className="px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-lg font-medium transition-colors inline-block"
      >
        前往管理後台
      </a>
    </div>
  );
}

// 這是外層頁面，必須包在 Suspense 裡
export default function Home() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
      <Suspense fallback={<div className="text-white">Loading...</div>}>
        <RedirectContent />
      </Suspense>
    </div>
  );
}