import { 
  collection, 
  query, 
  orderBy, 
  getDocs, 
  deleteDoc, 
  doc,
  Timestamp 
} from 'firebase/firestore';
import { db } from './firebase';
import { Post } from '@/types';

/**
 * Fetch all posts from Firestore, ordered by timestamp (newest first)
 */
export async function fetchAllPosts(): Promise<Post[]> {
  if (!db) {
    throw new Error('Firebase is not initialized');
  }

  try {
    const postsRef = collection(db, 'creator_posts');
    const q = query(postsRef, orderBy('timestamp', 'desc'));
    const snapshot = await getDocs(q);
    
    const posts: Post[] = snapshot.docs.map((docSnapshot) => {
      const data = docSnapshot.data();
      return {
        id: docSnapshot.id,
        authorId: data.authorId || '',
        authorName: data.authorName || 'Unknown',
        text: data.text || data.content || '',
        imageUrl: data.imageUrl,
        timestamp: data.timestamp || Timestamp.now(),
        category: data.category,
        likesCount: data.likesCount || 0,
        url: data.url,
        ogTitle: data.ogTitle,
        ogDescription: data.ogDescription,
        ogImageUrl: data.ogImageUrl,
        reportCount: data.reportCount || 0,
        isHidden: data.isHidden || false,
      };
    });
    
    return posts;
  } catch (error) {
    console.error('Error fetching posts:', error);
    throw error;
  }
}

/**
 * Delete a post by ID
 * Note: This works because Firestore Rules allow Admins to delete
 */
export async function deletePost(postId: string): Promise<void> {
  if (!db) {
    throw new Error('Firebase is not initialized');
  }

  try {
    const postRef = doc(db, 'creator_posts', postId);
    await deleteDoc(postRef);
  } catch (error) {
    console.error('Error deleting post:', error);
    throw error;
  }
}
