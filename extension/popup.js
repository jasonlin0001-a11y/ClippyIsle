// 1. 引入 Firebase (使用 CDN 模組方式)
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getAuth, signInWithEmailAndPassword, signOut, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js';
import { getFirestore, collection, addDoc, serverTimestamp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';

// ⚠️ 請填入您的 Firebase Config (跟 Web 專案的一樣)
const firebaseConfig = {
  apiKey: "AIzaSyD22rdFa7pQCqtf-Dd0j0jtEbBLIOnurto",
  authDomain: "cc-isle.firebaseapp.com",
  projectId: "cc-isle",
  storageBucket: "cc-isle.firebasestorage.app",
  messagingSenderId: "948415401164",
  appId: "1:948415401164:web:94942a2631331e3e4d4669"
};

// 初始化
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// UI 元素
const loginScreen = document.getElementById('login-screen');
const mainScreen = document.getElementById('main-screen');
const statusDiv = document.getElementById('status');
const titleInput = document.getElementById('page-title');

// 監聽登入狀態
onAuthStateChanged(auth, (user) => {
  if (user) {
    showMainScreen(user);
  } else {
    showLoginScreen();
  }
});

function showLoginScreen() {
  loginScreen.classList.remove('hidden');
  mainScreen.classList.add('hidden');
  statusDiv.textContent = '';
}

function showMainScreen(user) {
  loginScreen.classList.add('hidden');
  mainScreen.classList.remove('hidden');
  statusDiv.textContent = `Logged in as ${user.email}`;

  // 自動抓取當前分頁標題
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (tabs[0]) {
      titleInput.value = tabs[0].title;
    }
  });
}

// 登入按鈕
document.getElementById('btn-login').addEventListener('click', async () => {
  const email = document.getElementById('email').value;
  const password = document.getElementById('password').value;
  statusDiv.textContent = 'Logging in...';
  
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (error) {
    statusDiv.textContent = 'Error: ' + error.message;
  }
});

// 登出按鈕
document.getElementById('btn-logout').addEventListener('click', () => {
  signOut(auth);
});

// 儲存按鈕 (核心功能)
document.getElementById('btn-save').addEventListener('click', async () => {
  const user = auth.currentUser;
  if (!user) return;

  const title = titleInput.value;
  const memo = document.getElementById('memo').value;
  const btn = document.getElementById('btn-save');

  btn.disabled = true;
  btn.textContent = 'Sending...';

  // 抓取當前網址
  chrome.tabs.query({ active: true, currentWindow: true }, async (tabs) => {
    const activeTab = tabs[0];
    const url = activeTab.url;

    try {
      // 寫入 Firestore (與 App 資料結構一致)
      await addDoc(collection(db, 'creator_posts'), {
        creator_uid: user.uid,
        authorName: user.email.split('@')[0], // 用 Email 前綴當作者名
        link_title: title,
        link_description: memo, // 這裡存 memo
        content_url: url,
        curator_note: memo,     // 這裡也存一份，確保 App 能顯示
        created_at: serverTimestamp(),
        isHidden: false,
        link_image: '', // 擴充功能暫時不抓圖，交給後端或留空
        type: 'web_clip' // 標記來源 (可選)
      });

      statusDiv.textContent = 'Saved successfully!';
      statusDiv.style.color = '#2dd4bf';
      
      // 1秒後關閉視窗
      setTimeout(() => {
        window.close();
      }, 1000);

    } catch (error) {
      console.error(error);
      statusDiv.textContent = 'Error saving: ' + error.message;
      statusDiv.style.color = 'red';
      btn.disabled = false;
      btn.textContent = 'Send to App';
    }
  });
});