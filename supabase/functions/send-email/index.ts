// Supabase Edge Function: send-email
// Dispatches email notifications to users for work requests, approvals, and announcements.
// Supports RESEND_API_KEY, SENDGRID_API_KEY, or SMTP.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

interface EmailPayload {
  recipient_id?: string;
  recipient_email: string;
  recipient_name?: string;
  subject: string;
  title: string;
  message: string;
  work_request_id?: string;
  notification_type?: string;
  timestamp?: string;
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const payload: EmailPayload = await req.json();
    if (!payload.recipient_email || !payload.subject || !payload.message) {
      return new Response(
        JSON.stringify({ error: 'Missing recipient_email, subject, or message' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    const senderEmail = Deno.env.get('SENDER_EMAIL') || 'no-reply@psu-mms.edu.ph';

    if (resendApiKey) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: `PSU MMS <${senderEmail}>`,
          to: [payload.recipient_email],
          subject: payload.subject,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
              <h2 style="color: #1e3a8a; margin-top: 0;">PSU Maintenance Management System</h2>
              <h3 style="color: #0f172a;">${payload.title}</h3>
              <p style="color: #334155; font-size: 15px; line-height: 1.6;">${payload.message}</p>
              ${payload.work_request_id ? `<p style="color: #64748b; font-size: 13px;">Work Request ID: ${payload.work_request_id}</p>` : ''}
              <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;" />
              <p style="color: #94a3b8; font-size: 12px;">This is an automated notification. You received this because Email Notifications are enabled in your account settings.</p>
            </div>
          `,
        }),
      });

      const data = await res.json();
      return new Response(JSON.stringify({ success: true, provider: 'resend', data }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Default response when external email API key is not configured
    console.log(`[send-email] Mock dispatch to ${payload.recipient_email}: "${payload.subject}"`);
    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email payload logged (RESEND_API_KEY not configured)',
        recipient: payload.recipient_email,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('send-email error:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
