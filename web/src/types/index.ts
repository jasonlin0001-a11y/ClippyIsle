import { Timestamp } from 'firebase/firestore';

export interface Post {
  id: string;
  creator_uid: string;
  created_at: Timestamp;
  // 為了相容各種新舊欄位
  link_title?: string;
  ogTitle?: string;
  link_description?: string;
  ogDescription?: string;
  link_image?: string;
  ogImageUrl?: string;
  content_url?: string;
  url?: string;
  authorName?: string;
  authorId?: string;
  isHidden?: boolean;
  [key: string]: any; // 允許額外欄位
}