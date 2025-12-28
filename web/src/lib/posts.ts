import { 
  collection, 
  getDocs, 
  query, 
  orderBy, 
  where, 
  deleteDoc, 
<<<<<<< Updated upstream
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
=======
  doc, 
  updateDoc, 
  Timestamp,
  Firestore // 1. 多引入這個型別
} from 'firebase/firestore';
import { db } from './firebase'; 
import { Post } from '@/types'; 

// 1. 獲取文章列表
export async function fetchAllPosts(userId?: string) {
  // 防呆：如果資料庫沒連上，直接回傳空陣列
>>>>>>> Stashed changes
  if (!db) {
    console.warn("Firestore not initialized");
    return [];
  }

  try {
<<<<<<< Updated upstream
    const postsRef = collection(db, 'creator_posts');
=======
    // 2. 修復點：加上 (db as Firestore) 告訴 TS 它是安全的
    const postsRef = collection(db as Firestore, 'creator_posts');
>>>>>>> Stashed changes
    let q;

    if (userId) {
      q = query(
        postsRef, 
        where('creator_uid', '==', userId), 
        orderBy('created_at', 'desc')
      );
    } else {
      q = query(postsRef, orderBy('created_at', 'desc'));
    }
<<<<<<< Updated upstream
    
    const snapshot = await getDocs(q);
    
    // 2. Map Firestore fields to Post interface used by PostList component
    const posts: Post[] = snapshot.docs.map((docSnapshot) => {
=======

    const snapshot = await getDocs(q);

    const posts = snapshot.docs.map((docSnapshot) => {
>>>>>>> Stashed changes
      const data = docSnapshot.data();
      
      return {
        id: docSnapshot.id,
<<<<<<< Updated upstream
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
=======
        ...data,
        ogTitle: data.link_title || data.ogTitle || data.title || '(No Title)',
        ogDescription: data.link_description || data.ogDescription || data.description || '',
        imageUrl: data.link_image || data.ogImageUrl || data.imageUrl || '',
        url: data.content_url || data.url || '',
        authorName: data.authorName || 'Unknown',
        authorId: data.creator_uid || data.authorId || '',
        timestamp: data.created_at || Timestamp.now(),
        created_at: data.created_at || Timestamp.now(),
        isHidden: data.isHidden || false,
      } as any;
>>>>>>> Stashed changes
    });

    return posts;
  } catch (error) {
    console.error('Error fetching posts:', error);
    return [];
  }
}

<<<<<<< Updated upstream
/**
 * Delete a post by ID
 */
export async function deletePost(postId: string): Promise<void> {
  if (!db) {
    throw new Error('Firebase is not initialized');
  }

=======
// 2. 刪除文章
export async function deletePost(postId: string) {
  if (!db) throw new Error("Firestore not initialized");
  
>>>>>>> Stashed changes
  try {
    // 3. 修復點：加上 (db as Firestore)
    await deleteDoc(doc(db as Firestore, 'creator_posts', postId));
    return true;
  } catch (error) {
    console.error('Error deleting post:', error);
    throw error;
  }
}

// 3. 更新文章
export async function updatePost(postId: string, updates: Partial<Post>) {
  if (!db) throw new Error("Firestore not initialized");

  try {
<<<<<<< Updated upstream
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
=======
    // 4. 修復點：加上 (db as Firestore)
    const postRef = doc(db as Firestore, 'creator_posts', postId);
    await updateDoc(postRef, updates);
    return true;
>>>>>>> Stashed changes
  } catch (error) {
    console.error('Error updating post:', error);
    throw error;
  }
}