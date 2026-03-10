import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // Allow MapLibre GL JS tiles from common sources
  images: {
    remotePatterns: [],
  },
};

export default nextConfig;
