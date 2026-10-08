import { NextResponse } from 'next/server';
import { RELEASE_CONFIG } from '@/config/release';

export const dynamic = 'force-dynamic';

export async function GET() {
  const token = process.env.GITHUB_TOKEN;

  // If GITHUB_TOKEN is available, fetch the authenticated pre-signed asset download URL
  if (token) {
    try {
      const assetUrl = `https://api.github.com/repos/${RELEASE_CONFIG.githubRepo}/releases/assets/${RELEASE_CONFIG.githubAssetId}`;
      const res = await fetch(assetUrl, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/octet-stream',
          'User-Agent': 'Sanchat-Website-Downloader',
        },
        redirect: 'manual',
      });

      // GitHub returns 302 with Location pointing to pre-signed S3 storage
      const location = res.headers.get('location');
      if (location) {
        return NextResponse.redirect(location, {
          status: 307,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
          },
        });
      }
    } catch (err) {
      console.error('Failed to resolve authenticated GitHub release asset:', err);
    }
  }

  // Fallback: direct latest release download URL
  return NextResponse.redirect(RELEASE_CONFIG.githubDirectDownloadUrl, {
    status: 307,
    headers: {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  });
}
