import { 
  collection, 
  query, 
  orderBy, 
  where,
  getDocs, 
  getDoc,
  deleteDoc, 
  updateDoc, // 新增這個
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
<<<<<<< HEAD
 * 抓取所有文章 (已修正為 Dashboard 專用格式)
=======
 * 檢查使用者是否為管理員
 * 邏輯：檢查 'admins' 集合中是否有該使用者的 ID
>>>>>>> copilot/create-firebase-function-scrape-metadata
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
<<<<<<< HEAD
    const q = query(postsRef, orderBy('created_at', 'desc'));
=======
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
    
>>>>>>> copilot/create-firebase-function-scrape-metadata
    const snapshot = await getDocs(q);
    
    // 2. 直接對應資料庫欄位，不隨意改名 (解決 Dashboard 空白問題)
    const posts: Post[] = snapshot.docs.map((docSnapshot) => {
      const data = docSnapshot.data();
      
<<<<<<< HEAD
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
=======
      // 做欄位對應
      return {
        id: docSnapshot.id,
        authorId: data.creator_uid || data.authorId || '',
        authorName: data.authorName || 'Unknown',
        
        text: data.curator_note || data.text || data.content || '',
        
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
>>>>>>> copilot/create-firebase-function-scrape-metadata
      };
    });
    
    return posts;
  } catch (error) {
    console.error('Error fetching posts:', error);
    throw error;
  }
}

/**
<<<<<<< HEAD
 * 刪除文章
=======
 * Delete a post by ID
>>>>>>> copilot/create-firebase-function-scrape-metadata
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
    const dbUpdates: any = {
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