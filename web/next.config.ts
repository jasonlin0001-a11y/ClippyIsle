import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // 強制輸出為靜態 HTML (這會產生 out 資料夾)
  output: 'export',
  
  // 關閉圖片優化 (靜態輸出不支援)
  images: {
    unoptimized: true,
  },
};

export default nextConfig;