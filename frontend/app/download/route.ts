import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  // Direct verified release binary served from Vercel Edge CDN (/downloads/sanchat-release.apk)
  return NextResponse.redirect(new URL('/downloads/sanchat-release.apk', request.url), {
    status: 307,
    headers: {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  });
}

