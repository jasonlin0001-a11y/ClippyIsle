'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { storage, db } from '@/lib/firebase';
import { Loader2, Image as ImageIcon, ArrowLeft, Plus, Clipboard } from 'lucide-react';

export default function CreatePostPage() {
  const { user, isAdmin, loading } = useAuth();
  const router = useRouter();
  
  const [linkUrl, setLinkUrl] = useState('');
  const [linkTitle, setLinkTitle] = useState('');
  const [linkDescription, setLinkDescription] = useState('');
  const [curatorNote, setCuratorNote] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Extract domain from URL
  const extractDomain = useCallback((url: string): string => {
    if (!url) return '';
    try {
      const urlObj = new URL(url);
      return urlObj.hostname;
    } catch {
      return '';
    }
  }, []);

  // Handle image from file
  const setImageFromFile = useCallback((file: File) => {
    setImageFile(file);
    const reader = new FileReader();
    reader.onloadend = () => {
      setImagePreview(reader.result as string);
    };
    reader.readAsDataURL(file);
  }, []);

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login');
    }
  }, [user, loading, router]);

  useEffect(() => {
    if (!loading && user && !isAdmin) {
      router.push('/');
    }
  }, [user, isAdmin, loading, router]);

  // Global paste event listener for images
  useEffect(() => {
    const handlePaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;

      for (let i = 0; i < items.length; i++) {
        if (items[i].type.indexOf('image') !== -1) {
          const file = items[i].getAsFile();
          if (file) {
            setImageFromFile(file);
            e.preventDefault();
            break;
          }
        }
      }
    };

    window.addEventListener('paste', handlePaste);
    return () => window.removeEventListener('paste', handlePaste);
  }, [setImageFromFile]);

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setImageFromFile(file);
    }
  };

  const handleRemoveImage = () => {
    setImageFile(null);
    setImagePreview(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!user) {
      setError('You must be logged in to create a post.');
      return;
    }

    if (!storage || !db) {
      setError('Firebase is not configured properly.');
      return;
    }

    setPublishing(true);

    try {
      let downloadURL = '';

      // Upload image to Firebase Storage if selected
      if (imageFile) {
        const fileName = `${Date.now()}_${imageFile.name}`;
        const storageRef = ref(storage, `post_images/${fileName}`);
        const snapshot = await uploadBytes(storageRef, imageFile);
        downloadURL = await getDownloadURL(snapshot.ref);
      }

      // Add document to Firestore
      const linkDomain = extractDomain(linkUrl);
      await addDoc(collection(db, 'creator_posts'), {
        creator_uid: user.uid,
        curator_note: curatorNote,
        content_url: linkUrl || '',
        link_image: downloadURL,
        created_at: serverTimestamp(),
        link_title: linkTitle.trim() || 'Shared Link',
        link_description: linkDescription,
        link_domain: linkDomain,
        isHidden: false,
        reportCount: 0,
      });

      // Redirect to dashboard on success
      router.push('/');
    } catch (err) {
      console.error('Error creating post:', err);
      setError(err instanceof Error ? err.message : 'Failed to create post. Please try again.');
    } finally {
      setPublishing(false);
    }
  };

  // Loading state
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

  // Not logged in or not admin - will redirect
  if (!user || !isAdmin) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-teal-500" />
          <p className="text-[#fafafa]/60">Redirecting...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0a0a] p-4 md:p-8">
      <div className="max-w-[600px] mx-auto">
        {/* Back Button */}
        <button
          onClick={() => router.push('/')}
          className="inline-flex items-center gap-2 text-[#fafafa]/60 hover:text-[#fafafa] mb-6 transition-colors"
        >
          <ArrowLeft className="h-5 w-5" />
          Back to Dashboard
        </button>

        {/* Form Card */}
        <div className="rounded-xl bg-[#1a1a1a] p-6 border border-[#2a2a2a]">
          <h1 className="text-2xl font-bold text-[#fafafa] mb-6">New Post</h1>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Link URL (Optional) */}
            <div>
              <label htmlFor="linkUrl" className="mb-2 block text-sm font-medium text-[#fafafa]/80">
                Link URL (Optional)
              </label>
              <input
                id="linkUrl"
                type="url"
                value={linkUrl}
                onChange={(e) => setLinkUrl(e.target.value)}
                placeholder="https://example.com"
                className="w-full rounded-lg bg-[#0a0a0a] py-3 px-4 text-[#fafafa] placeholder:text-[#fafafa]/30 border border-[#2a2a2a] focus:border-teal-500 focus:outline-none focus:ring-1 focus:ring-teal-500 transition-colors"
              />
              {linkUrl && extractDomain(linkUrl) && (
                <p className="mt-1 text-xs text-[#fafafa]/40">
                  Domain: {extractDomain(linkUrl)}
                </p>
              )}
            </div>

            {/* Link Title */}
            <div>
              <label htmlFor="linkTitle" className="mb-2 block text-sm font-medium text-[#fafafa]/80">
                Link Title
              </label>
              <input
                id="linkTitle"
                type="text"
                value={linkTitle}
                onChange={(e) => setLinkTitle(e.target.value)}
                placeholder="Enter a title (defaults to 'Shared Link')"
                className="w-full rounded-lg bg-[#0a0a0a] py-3 px-4 text-[#fafafa] placeholder:text-[#fafafa]/30 border border-[#2a2a2a] focus:border-teal-500 focus:outline-none focus:ring-1 focus:ring-teal-500 transition-colors"
              />
            </div>

            {/* Link Description (Optional) */}
            <div>
              <label htmlFor="linkDescription" className="mb-2 block text-sm font-medium text-[#fafafa]/80">
                Link Description (Optional)
              </label>
              <input
                id="linkDescription"
                type="text"
                value={linkDescription}
                onChange={(e) => setLinkDescription(e.target.value)}
                placeholder="Brief description of the link"
                className="w-full rounded-lg bg-[#0a0a0a] py-3 px-4 text-[#fafafa] placeholder:text-[#fafafa]/30 border border-[#2a2a2a] focus:border-teal-500 focus:outline-none focus:ring-1 focus:ring-teal-500 transition-colors"
              />
            </div>

            {/* Image Upload */}
            <div>
              <label className="mb-2 block text-sm font-medium text-[#fafafa]/80">
                Image
              </label>
              
              {imagePreview ? (
                <div className="relative">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={imagePreview}
                    alt="Preview"
                    className="w-full max-h-64 object-contain rounded-lg bg-[#0a0a0a] border border-[#2a2a2a]"
                  />
                  <button
                    type="button"
                    onClick={handleRemoveImage}
                    className="absolute top-2 right-2 bg-red-500 hover:bg-red-600 text-white rounded-full p-1 transition-colors"
                  >
                    <svg className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                    </svg>
                  </button>
                </div>
              ) : (
                <div
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full rounded-lg bg-[#0a0a0a] py-12 px-4 border-2 border-dashed border-[#2a2a2a] hover:border-teal-500/50 cursor-pointer transition-colors flex flex-col items-center justify-center gap-3"
                >
                  <div className="flex items-center gap-2">
                    <ImageIcon className="h-8 w-8 text-[#fafafa]/30" />
                    <Clipboard className="h-6 w-6 text-[#fafafa]/30" />
                  </div>
                  <p className="text-[#fafafa]/60 text-sm">Click to select or paste an image (Cmd+V / Ctrl+V)</p>
                </div>
              )}
              
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleImageChange}
                className="hidden"
              />
            </div>

            {/* Note/Content */}
            <div>
              <label htmlFor="curatorNote" className="mb-2 block text-sm font-medium text-[#fafafa]/80">
                Note / Content
              </label>
              <textarea
                id="curatorNote"
                value={curatorNote}
                onChange={(e) => setCuratorNote(e.target.value)}
                placeholder="Add a note or description..."
                rows={4}
                className="w-full rounded-lg bg-[#0a0a0a] py-3 px-4 text-[#fafafa] placeholder:text-[#fafafa]/30 border border-[#2a2a2a] focus:border-teal-500 focus:outline-none focus:ring-1 focus:ring-teal-500 transition-colors resize-none"
              />
            </div>

            {/* Error Message */}
            {error && (
              <div className="rounded-lg bg-red-500/10 border border-red-500/20 p-3">
                <p className="text-sm text-red-400">{error}</p>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={publishing}
              className="w-full rounded-lg bg-gradient-to-r from-teal-500 to-blue-600 py-3 font-medium text-white hover:from-teal-600 hover:to-blue-700 focus:outline-none focus:ring-2 focus:ring-teal-500 focus:ring-offset-2 focus:ring-offset-[#1a1a1a] disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2"
            >
              {publishing ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Publishing...
                </>
              ) : (
                <>
                  <Plus className="h-5 w-5" />
                  Publish
                </>
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
