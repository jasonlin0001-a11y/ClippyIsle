'use client';

import { useState, useMemo } from 'react'; // 1. 引入 useMemo 做效能優化
import { Post } from '@/types';
import { deletePost, updatePost } from '@/lib/posts';
import { 
  Trash2, 
  ExternalLink, 
  AlertTriangle, 
  Eye, 
  EyeOff, 
  Image as ImageIcon, 
  Edit2, 
  Calendar, 
  Link as LinkIcon,
  Search, // 2. 引入搜尋圖示
  X       // 2. 引入清除圖示
} from 'lucide-react';
import EditPostModal from './EditPostModal';

// 圖片代理函式
const getProxyUrl = (url: string) => {
  if (!url) return '';
  if (url.startsWith('https://wsrv.nl')) return url;
  return `https://wsrv.nl/?url=${encodeURIComponent(url)}&w=400&h=400&fit=cover`;
};

interface PostListProps {
  posts: Post[];
  onPostDeleted: (postId: string) => void;
  onPostUpdated?: () => void;
}

export default function PostList({ posts, onPostDeleted, onPostUpdated }: PostListProps) {
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [failedImages, setFailedImages] = useState<Set<string>>(new Set());
  const [editingPost, setEditingPost] = useState<Post | null>(null);
  
  // 3. 新增搜尋狀態
  const [searchTerm, setSearchTerm] = useState('');

  // 4. 即時篩選邏輯 (使用 useMemo 避免不必要的重複運算)
  const filteredPosts = useMemo(() => {
    if (!searchTerm.trim()) return posts;

    const lowerTerm = searchTerm.toLowerCase();
    return posts.filter((post) => {
      const title = (post.ogTitle || post.authorName || '').toLowerCase();
      const content = (post.ogDescription || post.text || '').toLowerCase();
      const author = (post.authorName || '').toLowerCase();
      
      return title.includes(lowerTerm) || 
             content.includes(lowerTerm) || 
             author.includes(lowerTerm);
    });
  }, [posts, searchTerm]);

  const handleDeleteClick = (postId: string) => setConfirmDeleteId(postId);

  const handleConfirmDelete = async (postId: string) => {
    setDeletingId(postId);
    try {
      await deletePost(postId);
      onPostDeleted(postId);
    } catch (error) {
      console.error('Failed to delete post:', error);
      alert('Failed to delete post.');
    } finally {
      setDeletingId(null);
      setConfirmDeleteId(null);
    }
  };

  const handleSaveEdit = async (postId: string, updates: Partial<Post>) => {
    await updatePost(postId, updates);
    setEditingPost(null);
    if (onPostUpdated) {
      onPostUpdated();
    } else {
      window.location.reload();
    }
  };

  const handleImageError = (postId: string) => {
    setFailedImages(prev => new Set(prev).add(postId));
  };

  const formatDate = (timestamp: { seconds: number }) => {
    if (!timestamp?.seconds) return '';
    return new Date(timestamp.seconds * 1000).toLocaleDateString('zh-TW', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
  };

  const getDomain = (url?: string) => {
    if (!url) return '';
    try {
      return new URL(url).hostname.replace('www.', '');
    } catch {
      return 'link';
    }
  };

  return (
    <div className="space-y-6">
      {/* 5. 搜尋列區域 */}
      <div className="relative">
        <div className="absolute inset-y-0 left-3 flex items-center pointer-events-none">
          <Search className="h-5 w-5 text-gray-500" />
        </div>
        <input
          type="text"
          placeholder="Search title, content or author..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full bg-[#121212] border border-[#333] text-white rounded-xl py-3 pl-10 pr-10 focus:outline-none focus:border-teal-500/50 focus:ring-1 focus:ring-teal-500/50 transition-all placeholder:text-gray-600"
        />
        {searchTerm && (
          <button
            onClick={() => setSearchTerm('')}
            className="absolute inset-y-0 right-3 flex items-center text-gray-500 hover:text-white transition-colors"
          >
            <X className="h-5 w-5" />
          </button>
        )}
      </div>

      {/* 6. 搜尋結果計數 (可選) */}
      {searchTerm && (
        <div className="text-xs text-gray-500 px-1">
          Found {filteredPosts.length} result{filteredPosts.length !== 1 && 's'}
        </div>
      )}

      {/* 7. 列表顯示 (改為顯示 filteredPosts) */}
      {filteredPosts.length === 0 ? (
        <div className="rounded-xl bg-[#1a1a1a] border border-[#2a2a2a] p-12 text-center">
          <p className="text-[#fafafa]/60">
            {searchTerm ? 'No matching posts found.' : 'No posts found.'}
          </p>
          {searchTerm && (
            <button 
              onClick={() => setSearchTerm('')}
              className="mt-2 text-teal-400 hover:text-teal-300 text-sm"
            >
              Clear search
            </button>
          )}
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {filteredPosts.map((post) => {
            const imageUrl = post.imageUrl || post.ogImageUrl;
            const showImage = imageUrl && !failedImages.has(post.id);
            const isConfirmingDelete = confirmDeleteId === post.id;
            
            // 標題顯示邏輯
            const displayTitle = post.ogTitle || post.authorName || 'Untitled';
            // 內文顯示邏輯
            const displayDescription = post.ogDescription || (post.ogTitle ? post.text : '') || 'No content...';

            return (
              <div 
                key={post.id} 
                className="group relative flex flex-col sm:flex-row gap-4 bg-[#121212] border border-[#2a2a2a] p-4 rounded-xl hover:border-teal-500/30 transition-all"
              >
                {/* 左側圖片 */}
                <div className="relative shrink-0 w-full sm:w-32 sm:h-32 rounded-lg overflow-hidden bg-[#1f1f1f] border border-[#333]">
                  {showImage ? (
<<<<<<< HEAD
<div className="relative h-12 w-12 rounded-lg overflow-hidden bg-[#2a2a2a]">
  {/* 修改：改用標準 img 標籤並加上 referrerPolicy="no-referrer" 來騙過 Meta 的防盜連 */}
  <img
    src={imageUrl}
    alt=""
    className="w-full h-full object-cover"
    referrerPolicy="no-referrer"
    onError={(e) => {
      // 圖片真的掛掉時，呼叫原本的 error handler 並顯示預設圖
      handleImageError(post.id);
      e.currentTarget.style.display = 'none'; // 或替換成預設圖
    }}
  />
</div>
=======
                    <img
                      src={getProxyUrl(imageUrl)}
                      alt=""
                      className="w-full h-full object-cover transition-transform group-hover:scale-105 duration-500"
                      onError={(e) => {
                        handleImageError(post.id);
                        e.currentTarget.style.display = 'none';
                      }}
                    />
>>>>>>> copilot/create-firebase-function-scrape-metadata
                  ) : (
                    <div className="w-full h-full flex items-center justify-center">
                      <ImageIcon className="h-8 w-8 text-[#fafafa]/20" />
                    </div>
                  )}
                  
                  {/* 狀態標籤 */}
                  <div className="absolute top-2 left-2 flex flex-col gap-1">
                    {post.isHidden && (
                      <div className="px-2 py-1 rounded-md bg-black/60 backdrop-blur-md border border-yellow-500/30 text-yellow-400 text-[10px] font-medium flex items-center gap-1">
                        <EyeOff className="w-3 h-3" /> Hidden
                      </div>
                    )}
                  </div>
                </div>

                {/* 中間內容區 */}
                <div className="flex-1 min-w-0 flex flex-col justify-between py-1">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between gap-4">
                      <h3 className="text-[#fafafa] font-bold text-lg line-clamp-1">
                        {displayTitle}
                      </h3>
                    </div>
                    <p className="text-[#a1a1a1] text-sm leading-relaxed line-clamp-2">
                      {displayDescription}
                    </p>
                  </div>

                  <div className="mt-4 flex flex-wrap items-center gap-3">
                    {post.url && (
                      <a 
                        href={post.url} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-[#2a2a2a] hover:bg-[#333] border border-[#333] text-xs text-[#ccc] transition-colors"
                      >
                        <LinkIcon className="w-3 h-3" />
                        {getDomain(post.url)}
                      </a>
                    )}
                    
                    <div className="flex items-center gap-1.5 text-xs text-[#666]">
                      <Calendar className="w-3 h-3" />
                      {formatDate(post.timestamp)}
                    </div>
                  </div>
                </div>

                {/* 右側動作區 */}
                <div className="flex sm:flex-col items-center sm:items-end justify-between sm:justify-start gap-2 pl-0 sm:pl-4 sm:border-l border-[#2a2a2a] min-w-[50px]">
                  {isConfirmingDelete ? (
                    <div className="flex flex-col gap-2 w-full animate-in fade-in zoom-in duration-200">
                      <button
                        onClick={() => handleConfirmDelete(post.id)}
                        className="px-3 py-1.5 text-xs font-medium bg-red-500 hover:bg-red-600 text-white rounded-lg w-full"
                        disabled={deletingId === post.id}
                      >
                        {deletingId ? '...' : 'Confirm'}
                      </button>
                      <button
                        onClick={() => setConfirmDeleteId(null)}
                        className="px-3 py-1.5 text-xs text-[#888] hover:text-white hover:bg-[#2a2a2a] rounded-lg w-full"
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <>
                      <button
                        onClick={() => setEditingPost(post)}
                        className="p-2 text-teal-400 hover:bg-teal-500/10 rounded-lg transition-colors"
                        title="Edit"
                      >
                        <Edit2 className="w-5 h-5" />
                      </button>
                      
                      <button
                        onClick={() => handleDeleteClick(post.id)}
                        className="p-2 text-[#666] hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                        title="Delete"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {editingPost && (
        <EditPostModal 
          post={editingPost}
          isOpen={!!editingPost}
          onClose={() => setEditingPost(null)}
          onSave={handleSaveEdit}
        />
      )}
    </div>
  );
}