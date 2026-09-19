// Supabase Edge Function: push-notifications
// Sends Firebase Cloud Messaging (FCM) push notifications when app_notifications rows are inserted.
// Supports FCM HTTP v1 API using a Firebase Service Account key.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: {
    id: string;
    title: string;
    message: string;
    target_role?: string;
    target_user_id?: string;
    target_page?: string;
    work_request_id?: string;
    chat_room_id?: string;
  };
}

// Generate Google OAuth2 Access Token from Service Account JSON
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  // Base64URL encode helper
  const b64 = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

  const header = { alg: 'RS256', typ: 'JWT' };
  const encodedHeader = b64(header);
  const encodedClaim = b64(claim);
  const unsignedToken = `${encodedHeader}.${encodedClaim}`;

  // Import private key
  const pem = serviceAccount.private_key;
  const binaryDerString = atob(
    pem
      .replace(/-----BEGIN PRIVATE KEY-----/g, '')
      .replace(/-----END PRIVATE KEY-----/g, '')
      .replace(/\s+/g, '')
  );
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer.buffer,
    { name: 'RSASSA-PKPKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  ).catch(async () => {
    // Fallback for standard RSASSA-PKCS1-v1_5 name
    return await crypto.subtle.importKey(
      'pkcs8',
      binaryDer.buffer,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign']
    );
  });

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedToken)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${unsignedToken}.${encodedSignature}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Failed to get Google access token: ${errorText}`);
  }

  const data = await res.json();
  return data.access_token;
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const payload: WebhookPayload = await req.json();
    const record = payload.record;
    if (!record || !record.title || !record.message) {
      return new Response(JSON.stringify({ error: 'Missing notification record' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountJson) {
      console.warn('FIREBASE_SERVICE_ACCOUNT environment variable is not set.');
      return new Response(
        JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT secret not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch destination tokens
    let tokens: string[] = [];

    if (record.target_user_id) {
      const { data } = await supabase
        .from('user_devices')
        .select('fcm_token')
        .eq('user_id', record.target_user_id);
      tokens = (data || []).map((d: any) => d.fcm_token).filter(Boolean);
    } else if (record.target_role && record.target_role !== 'all') {
      const targetRoles =
        record.target_role === 'admin' || record.target_role === 'campadmin'
          ? ['admin', 'campadmin']
          : [record.target_role];
      const { data } = await supabase
        .from('user_devices')
        .select('fcm_token, users!inner(role, is_active)')
        .in('users.role', targetRoles)
        .eq('users.is_active', true);
      tokens = (data || []).map((d: any) => d.fcm_token).filter(Boolean);
    } else {
      const { data } = await supabase.from('user_devices').select('fcm_token');
      tokens = (data || []).map((d: any) => d.fcm_token).filter(Boolean);
    }

    // Deduplicate tokens
    tokens = Array.from(new Set(tokens));

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No registered device tokens found for target' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const accessToken = await getAccessToken(serviceAccount);
    const results: any[] = [];

    // Send to each device token via FCM HTTP v1 API
    for (const token of tokens) {
      const fcmMessage = {
        message: {
          token,
          notification: {
            title: record.title,
            body: record.message,
          },
          data: {
            notification_id: record.id || '',
            target_page: record.target_page || '',
            work_request_id: record.work_request_id || '',
            chat_room_id: record.chat_room_id || '',
            target_user_id: record.target_user_id || '',
            target_role: record.target_role || '',
            created_at: new Date().toISOString(),
          },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'psu_mms_notifications',
              icon: 'ic_launcher',
              sound: 'default',
              default_sound: true,
              default_vibrate_timings: true,
            },
          },
        },
      };

      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmMessage),
        }
      );

      const resBody = await res.json();
      results.push({ token, status: res.status, response: resBody });

      // Clean up invalid or unregistered tokens
      if (
        resBody.error &&
        (resBody.error.details?.some((d: any) => d.errorCode === 'UNREGISTERED') ||
          resBody.error.message?.includes('not a valid FCM registration token'))
      ) {
        await supabase.from('user_devices').delete().eq('fcm_token', token);
      }
    }

    return new Response(JSON.stringify({ sentCount: tokens.length, results }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Edge Function error:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
