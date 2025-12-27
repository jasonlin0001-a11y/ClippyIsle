'use client';

import { useState } from 'react';
import { Post } from '@/types';
import { X, Save, Loader2 } from 'lucide-react';

interface EditPostModalProps {
  post: Post;
  isOpen: boolean;
  onClose: () => void;
  onSave: (postId: string, updates: Partial<Post>) => Promise<void>;
}

export default function EditPostModal({ post, isOpen, onClose, onSave }: EditPostModalProps) {
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    ogTitle: post.ogTitle || '',
    ogDescription: post.ogDescription || '',
    text: post.text || '', // Curator Note
    isHidden: post.isHidden || false
  });

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await onSave(post.id, formData);
      onClose();
    } catch (error) {
      console.error('Failed to update post', error);
      alert('Failed to update post');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="w-full max-w-lg rounded-xl bg-[#1a1a1a] border border-[#333] shadow-2xl overflow-hidden">
        
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[#333]">
          <h3 className="text-lg font-semibold text-white">Edit Post</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          
          {/* Title */}
          <div className="space-y-2">
            <label className="text-xs font-medium text-gray-400 uppercase">Link Title</label>
            <input
              type="text"
              value={formData.ogTitle}
              onChange={(e) => setFormData({...formData, ogTitle: e.target.value})}
              className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg px-4 py-2 text-white focus:outline-none focus:border-teal-500 transition-colors"
            />
          </div>

          {/* Description */}
          <div className="space-y-2">
            <label className="text-xs font-medium text-gray-400 uppercase">Link Description</label>
            <textarea
              rows={3}
              value={formData.ogDescription}
              onChange={(e) => setFormData({...formData, ogDescription: e.target.value})}
              className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg px-4 py-2 text-white focus:outline-none focus:border-teal-500 transition-colors resize-none"
            />
          </div>

          {/* Curator Note */}
          <div className="space-y-2">
            <label className="text-xs font-medium text-teal-400 uppercase">Curator Note (Your Comment)</label>
            <textarea
              rows={2}
              value={formData.text}
              onChange={(e) => setFormData({...formData, text: e.target.value})}
              className="w-full bg-[#0a0a0a] border border-[#333] rounded-lg px-4 py-2 text-white focus:outline-none focus:border-teal-500 transition-colors resize-none"
              placeholder="Add your thoughts..."
            />
          </div>

          {/* Visibility Toggle */}
          <div className="flex items-center gap-3 pt-2">
            <input
              type="checkbox"
              id="isHidden"
              checked={formData.isHidden}
              onChange={(e) => setFormData({...formData, isHidden: e.target.checked})}
              className="w-4 h-4 rounded border-gray-600 bg-[#0a0a0a] text-teal-500 focus:ring-teal-500"
            />
            <label htmlFor="isHidden" className="text-sm text-gray-300 cursor-pointer">
              Hide this post from App
            </label>
          </div>

          {/* Footer Actions */}
          <div className="flex justify-end gap-3 pt-4 border-t border-[#333] mt-6">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm text-gray-400 hover:text-white hover:bg-[#333] rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="inline-flex items-center gap-2 px-6 py-2 text-sm font-medium text-white bg-teal-600 hover:bg-teal-500 rounded-lg transition-colors disabled:opacity-50"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
              Save Changes
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}