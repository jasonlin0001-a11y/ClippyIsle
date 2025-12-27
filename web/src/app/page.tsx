'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
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
      </div>
    );
  }

  if (status === 'found') {
    return (
      <div className="text-center p-8 bg-[#1a1a1a] rounded-xl border border-[#2a2a2a] max-w-md shadow-2xl">
        <h1 className="text-2xl font-bold text-[#fafafa] mb-4">找到了！</h1>
        <p className="text-[#fafafa]/60 mb-6">這篇文章存在，正在嘗試開啟 App...</p>
        <button className="px-6 py-3 bg-teal-600 hover:bg-teal-500 text-white rounded-lg font-medium transition-colors shadow-lg shadow-teal-900/20">
          開啟 CC ISLE App
        </button>
      </div>
    );
  }

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
    </div>
  );
}

export default function Home() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4">
      <Suspense fallback={<div className="text-white">Loading...</div>}>
        <RedirectContent />
      </Suspense>
    </div>
  );
}