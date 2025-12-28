/** @type {import('next').NextConfig} */
const nextConfig = {
  // 強制 Next.js 產生靜態匯出資料夾 'out'
  output: 'export',
  
  // 關閉靜態匯出不支援的圖片優化功能
  images: {
    unoptimized: true,
  },
};

module.exports = nextConfig;