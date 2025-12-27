'use client';

import { useState } from 'react';
import Image from 'next/image';
import { Post } from '@/types';
import { deletePost } from '@/lib/posts';
import { Trash2, ExternalLink, AlertTriangle, Eye, EyeOff, Image as ImageIcon } from 'lucide-react';

interface PostListProps {
  posts: Post[];
  onPostDeleted: (postId: string) => void;
}

export default function PostList({ posts, onPostDeleted }: PostListProps) {
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [failedImages, setFailedImages] = useState<Set<string>>(new Set());

  const handleDeleteClick = (postId: string) => {
    setConfirmDeleteId(postId);
  };

  const handleConfirmDelete = async (postId: string) => {
    setDeletingId(postId);
    try {
      await deletePost(postId);
      onPostDeleted(postId);
    } catch (error) {
      console.error('Failed to delete post:', error);
      alert('Failed to delete post. Please try again.');
    } finally {
      setDeletingId(null);
      setConfirmDeleteId(null);
    }
  };

  const handleCancelDelete = () => {
    setConfirmDeleteId(null);
  };

  const handleImageError = (postId: string) => {
    setFailedImages(prev => new Set(prev).add(postId));
  };

  const formatDate = (timestamp: { seconds: number }) => {
    if (!timestamp?.seconds) return 'N/A';
    return new Date(timestamp.seconds * 1000).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const truncateText = (text: string, maxLength: number = 50) => {
    if (!text) return 'No content';
    return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
  };

  if (posts.length === 0) {
    return (
      <div className="rounded-lg bg-[#1a1a1a] border border-[#2a2a2a] p-8 text-center">
        <p className="text-[#fafafa]/60">No posts found.</p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-[#2a2a2a] text-left text-sm text-[#fafafa]/60">
            <th className="px-4 py-3 font-medium">Image</th>
            <th className="px-4 py-3 font-medium">Content</th>
            <th className="px-4 py-3 font-medium">Author</th>
            <th className="px-4 py-3 font-medium">Date</th>
            <th className="px-4 py-3 font-medium">Status</th>
            <th className="px-4 py-3 font-medium text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          {posts.map((post) => {
            const imageUrl = post.imageUrl || post.ogImageUrl;
            const showImage = imageUrl && !failedImages.has(post.id);
            
            return (
              <tr 
                key={post.id} 
                className="border-b border-[#2a2a2a] hover:bg-[#1a1a1a] transition-colors"
              >
                {/* Image */}
                <td className="px-4 py-3">
                  {showImage ? (
                    <div className="relative h-12 w-12 rounded-lg overflow-hidden bg-[#2a2a2a]">
                      <Image
                        src={imageUrl}
                        alt=""
                        fill
                        className="object-cover"
                        onError={() => handleImageError(post.id)}
                        unoptimized
                      />
                    </div>
                  ) : (
                    <div className="h-12 w-12 rounded-lg bg-[#2a2a2a] flex items-center justify-center">
                      <ImageIcon className="h-5 w-5 text-[#fafafa]/30" />
                    </div>
                  )}
                </td>

                {/* Content */}
                <td className="px-4 py-3 max-w-xs">
                  <div className="text-sm text-[#fafafa]">
                    {truncateText(post.text || post.ogTitle || '', 60)}
                  </div>
                  {post.url && (
                    <a 
                      href={post.url} 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-xs text-teal-400 hover:text-teal-300 mt-1"
                    >
                      <ExternalLink className="h-3 w-3" />
                      Link
                    </a>
                  )}
                </td>

                {/* Author */}
                <td className="px-4 py-3">
                  <span className="text-sm text-[#fafafa]/80">{post.authorName}</span>
                </td>

                {/* Date */}
                <td className="px-4 py-3">
                  <span className="text-xs text-[#fafafa]/60">{formatDate(post.timestamp)}</span>
                </td>

                {/* Status */}
                <td className="px-4 py-3">
                  <div className="flex flex-col gap-1">
                    {post.isHidden && (
                      <span className="inline-flex items-center gap-1 text-xs text-yellow-400 bg-yellow-400/10 rounded px-2 py-0.5">
                        <EyeOff className="h-3 w-3" />
                        Hidden
                      </span>
                    )}
                    {(post.reportCount || 0) > 0 && (
                      <span className="inline-flex items-center gap-1 text-xs text-red-400 bg-red-400/10 rounded px-2 py-0.5">
                        <AlertTriangle className="h-3 w-3" />
                        {post.reportCount} reports
                      </span>
                    )}
                    {!post.isHidden && (post.reportCount || 0) === 0 && (
                      <span className="inline-flex items-center gap-1 text-xs text-green-400 bg-green-400/10 rounded px-2 py-0.5">
                        <Eye className="h-3 w-3" />
                        Visible
                      </span>
                    )}
                  </div>
                </td>

                {/* Actions */}
                <td className="px-4 py-3 text-right">
                  {confirmDeleteId === post.id ? (
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={handleCancelDelete}
                        className="px-3 py-1 text-xs text-[#fafafa]/60 hover:text-[#fafafa] border border-[#3a3a3a] rounded transition-colors"
                        disabled={deletingId === post.id}
                      >
                        Cancel
                      </button>
                      <button
                        onClick={() => handleConfirmDelete(post.id)}
                        className="px-3 py-1 text-xs text-white bg-red-500 hover:bg-red-600 rounded transition-colors disabled:opacity-50"
                        disabled={deletingId === post.id}
                      >
                        {deletingId === post.id ? 'Deleting...' : 'Confirm'}
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => handleDeleteClick(post.id)}
                      className="p-2 text-red-400 hover:text-red-300 hover:bg-red-500/10 rounded-lg transition-colors"
                      title="Delete post"
                    >
                      <Trash2 className="h-5 w-5" />
                    </button>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
