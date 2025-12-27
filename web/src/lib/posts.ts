import { 
  collection, 
  query, 
  orderBy, 
  where,
  getDocs, 
  getDoc,
  deleteDoc, 
  updateDoc,
  doc,
  Timestamp 
} from 'firebase/firestore';
import { db } from './firebase';
import { Post } from '@/types';

// Re-export Post type for convenience
export type { Post } from '@/types';

/**
 * 檢查使用者是否為管理員
 * 邏輯：檢查 'admins' 集合中是否有該使用者的 ID
 */
async function checkIsAdmin(userId: string): Promise<boolean> {
  if (!db || !userId) return false;
  try {
    const adminRef = doc(db, 'admins', userId);
    const adminSnap = await getDoc(adminRef);
    return adminSnap.exists();
  } catch (e) {
    console.error("Check admin failed", e);
    return false;
  }
}

/**
 * 抓取文章 (已加入權限分級)
 * @param currentUserId 當前登入的使用者 ID
 */
export async function fetchAllPosts(currentUserId?: string): Promise<Post[]> {
  if (!db) {
    throw new Error('Firebase is not initialized');
  }

  // 如果沒有傳入 UID (未登入)，直接回傳空陣列
  if (!currentUserId) {
    return [];
  }

  try {
    const postsRef = collection(db, 'creator_posts');
    let q;

    // 1. 先判斷身分
    const isAdmin = await checkIsAdmin(currentUserId);

    if (isAdmin) {
      // 👑 管理員：看全部 (依時間排序)
      console.log(`User ${currentUserId} is Admin. Fetching ALL posts.`);
      q = query(postsRef, orderBy('created_at', 'desc'));
    } else {
      // 👤 一般創作者：只看自己的 (篩選 creator_uid + 時間排序)
      console.log(`User ${currentUserId} is Creator. Fetching OWN posts.`);
      q = query(
        postsRef, 
        where('creator_uid', '==', currentUserId), 
        orderBy('created_at', 'desc')
      );
    }
    
    const snapshot = await getDocs(q);
    
    // 2. Map Firestore fields to Post interface used by PostList component
    const posts: Post[] = snapshot.docs.map((docSnapshot) => {
      const data = docSnapshot.data();
      
      return {
        id: docSnapshot.id,
        authorId: data.creator_uid || data.authorId || '',
        authorName: data.authorName || 'Unknown',
        
        text: data.curator_note || data.text || '',
        
        imageUrl: data.link_image || data.imageUrl,
        
        timestamp: data.created_at || data.timestamp || Timestamp.now(),
        
        category: data.category,
        likesCount: data.likesCount || 0,
        
        url: data.content_url || data.url,
        
        ogTitle: data.link_title || data.ogTitle,
        ogDescription: data.link_description || data.ogDescription,
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

/**
 * Update a post
 * 允許修改標題、描述、筆記與隱藏狀態
 */
export async function updatePost(postId: string, updates: Partial<Post>): Promise<void> {
  if (!db) throw new Error('Firebase is not initialized');

  try {
    const postRef = doc(db, 'creator_posts', postId);
    
    // 將前端的欄位名稱轉換回資料庫的欄位名稱
    const dbUpdates: Record<string, unknown> = {
      updated_at: Timestamp.now()
    };

    // 對應前端欄位到 Firestore 欄位
    if (updates.text !== undefined) dbUpdates.curator_note = updates.text;
    if (updates.ogTitle !== undefined) dbUpdates.link_title = updates.ogTitle;
    if (updates.ogDescription !== undefined) dbUpdates.link_description = updates.ogDescription;
    if (updates.isHidden !== undefined) dbUpdates.isHidden = updates.isHidden;

    await updateDoc(postRef, dbUpdates);
  } catch (error) {
    console.error('Error updating post:', error);
    throw error;
  }
}