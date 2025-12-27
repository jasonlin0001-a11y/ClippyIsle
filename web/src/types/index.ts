// Data models matching iOS app Firestore schema

import { Timestamp } from 'firebase/firestore';

export interface Post {
  id: string;
  authorId: string;
  authorName: string;
  text: string;
  imageUrl?: string;
  timestamp: Timestamp;
  category?: string;
  likesCount: number;
  // Additional fields from iOS model
  url?: string;
  ogTitle?: string;
  ogDescription?: string;
  ogImageUrl?: string;
  reportCount?: number;
  isHidden?: boolean;
}

export interface User {
  id: string;
  displayName: string;
  email?: string;
  photoURL?: string;
  bio?: string;
  followersCount: number;
  followingCount: number;
  createdAt: Timestamp;
}

export interface Admin {
  id: string;
  name?: string;
  role?: string;
}
