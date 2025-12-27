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
 * Fetch all posts from Firestore, ordered by created_at (newest first)
 */
export async function fetchAllPosts(): Promise<Post[]> {
  if (!db) {
    throw new Error('Firebase is not initialized');
  }

  try {
    const postsRef = collection(db, 'creator_posts');
    
    // 修正 1: 資料庫排序欄位是 created_at
    const q = query(postsRef, orderBy('created_at', 'desc'));
    
    const snapshot = await getDocs(q);
    
    const posts: Post[] = snapshot.docs.map((docSnapshot) => {
      const data = docSnapshot.data();
      
      // 修正 2: 這裡做欄位對應 (左邊是程式用的，右邊是資料庫有的)
      return {
        id: docSnapshot.id,
        // 資料庫是 creator_uid，若沒有則找 authorId，再沒有就給空字串
        authorId: data.creator_uid || data.authorId || '',
        authorName: data.authorName || 'Unknown',
        
        // 資料庫筆記是 curator_note，對應到這裡的 text
        text: data.curator_note || data.text || data.content || '',
        
        // 嘗試抓取連結圖片
        imageUrl: data.link_image || data.imageUrl,
        
        // 資料庫時間是 created_at
        timestamp: data.created_at || data.timestamp || Timestamp.now(),
        
        category: data.category,
        likesCount: data.likesCount || 0,
        
        // 資料庫連結是 content_url
        url: data.content_url || data.url,
        
        // 對應連結標題與描述
        ogTitle: data.link_title || data.ogTitle,
        ogDescription: data.link_description || data.ogDescription,
        ogImageUrl: data.ogImageUrl, // 若資料庫沒有這個欄位，會是 undefined
        
        // 保留原本的計數與隱藏邏輯
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
    // 這裡也要確保是指向 creator_posts
    const postRef = doc(db, 'creator_posts', postId);
    await deleteDoc(postRef);
  } catch (error) {
    console.error('Error deleting post:', error);
    throw error;
  }
}