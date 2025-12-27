/** @type {import('next').NextConfig} */
const nextConfig = {
  // 👇 強制靜態匯出，產生 out 資料夾 (這是我們唯一的目標)
  output: 'export',
  
  // 關閉圖片優化 (靜態匯出模式必備，否則會報錯)
  images: {
    unoptimized: true,
  },
};

module.exports = nextConfig;