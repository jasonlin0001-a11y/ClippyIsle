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

// 1. 直接在這裡定義並匯出 Post 介面 (解決 Build Error)
export interface Post {
  id: string;
  creator_uid: string;
  curator_note?: string; // 筆記
  content_url?: string;  // 原始連結
  
  // 連結預覽資料
  link_title?: string;
  link_description?: string;
  link_image?: string;
  link_domain?: string;
  
  created_at?: any;      // 時間戳記
}

/**
 * 抓取所有文章 (已修正為 Dashboard 專用格式)
 */
export async function fetchAllPosts(): Promise<Post[]> {
  if (!db) {
    throw new Error('Firebase is not initialized');
  }

  try {
    const postsRef = collection(db, 'creator_posts');
    const q = query(postsRef, orderBy('created_at', 'desc'));
    const snapshot = await getDocs(q);
    
    // 2. 直接對應資料庫欄位，不隨意改名 (解決 Dashboard 空白問題)
    const posts: Post[] = snapshot.docs.map((docSnapshot) => {
      const data = docSnapshot.data();
      
      return {
        id: docSnapshot.id,
        creator_uid: data.creator_uid || data.authorId || '',
        
        // 直接使用資料庫的原名，確保 Dashboard 讀得到
        curator_note: data.curator_note || data.text || '',
        content_url: data.content_url || data.url || '',
        
        link_title: data.link_title || data.ogTitle || '',
        link_description: data.link_description || data.ogDescription || '',
        link_image: data.link_image || data.imageUrl || '', // 關鍵修正
        link_domain: data.link_domain || '',
        
        created_at: data.created_at || Timestamp.now(),
      };
    });
    
    return posts;
  } catch (error) {
    console.error('Error fetching posts:', error);
    throw error;
  }
}

/**
 * 刪除文章
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