// Supabase Edge Function: send-email
// Dispatches email notifications to users for work requests, approvals, announcements,
// and newly created user account credentials.
// Supports GMAIL_USER + GMAIL_APP_PASSWORD (Gmail SMTP), RESEND_API_KEY, or Mock fallback.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import nodemailer from 'npm:nodemailer@6.9.10';

interface EmailPayload {
  recipient_id?: string;
  recipient_email: string;
  recipient_name?: string;
  subject: string;
  title: string;
  message: string;
  work_request_id?: string;
  notification_type?: string;
  default_password?: string;
  role?: string;
  html?: string;
  timestamp?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', {
        status: 405,
        headers: corsHeaders,
      });
    }

    const payload: EmailPayload = await req.json();
    if (!payload.recipient_email || !payload.subject || !payload.message) {
      return new Response(
        JSON.stringify({ error: 'Missing recipient_email, subject, or message' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let htmlBody = payload.html;

    if (!htmlBody) {
      const isAccountCreated =
        payload.notification_type === 'account_created' || Boolean(payload.default_password);

      if (isAccountCreated && payload.default_password) {
        htmlBody = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 14px; background-color: #ffffff;">
        <div style="background: linear-gradient(135deg, #1e3a8a, #0284c7); padding: 20px 24px; border-radius: 10px; margin-bottom: 24px; text-align: center;">
          <h2 style="color: #ffffff; margin: 0; font-size: 21px; font-weight: 800; letter-spacing: 0.5px;">PSU Maintenance Management System</h2>
          <p style="color: #bae6fd; margin: 6px 0 0 0; font-size: 13.5px; font-weight: 500;">E-Ayos Account Credentials</p>
        </div>

        <h3 style="color: #0f172a; margin-top: 0; font-size: 18px; font-weight: 700;">Welcome, ${payload.recipient_name || 'User'}!</h3>
        <p style="color: #334155; font-size: 15px; line-height: 1.6;">
          Your account has been successfully created by the System Administrator. Below are your official login credentials:
        </p>

        <div style="background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 7px 0; color: #64748b; font-size: 14px; width: 140px; font-weight: 600;">Email Address:</td>
              <td style="padding: 7px 0; color: #0f172a; font-size: 14px; font-weight: 700;">${payload.recipient_email}</td>
            </tr>
            <tr>
              <td style="padding: 7px 0; color: #64748b; font-size: 14px; font-weight: 600;">Default Password:</td>
              <td style="padding: 7px 0;">
                <span style="background-color: #e0f2fe; color: #0369a1; padding: 5px 12px; border-radius: 6px; font-family: Consolas, Monaco, monospace; font-size: 15px; font-weight: 800; border: 1px solid #bae6fd; letter-spacing: 0.5px;">
                  ${payload.default_password}
                </span>
              </td>
            </tr>
            ${payload.role ? `<tr>
              <td style="padding: 7px 0; color: #64748b; font-size: 14px; font-weight: 600;">Designated Role:</td>
              <td style="padding: 7px 0; color: #0f172a; font-size: 14px; font-weight: 600;">${payload.role}</td>
            </tr>` : ''}
          </table>
        </div>

        <div style="background-color: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px 16px; margin: 20px 0; border-radius: 6px;">
          <p style="margin: 0; color: #b45309; font-size: 13.5px; line-height: 1.5;">
            <strong>⚠️ Security Requirement:</strong> For your protection, you will be prompted to change this default password immediately upon your first sign in.
          </p>
        </div>

        <div style="text-align: center; margin: 28px 0 20px 0;">
          <a href="https://project-drr8n.vercel.app" style="background: linear-gradient(135deg, #0284c7, #1e3a8a); color: #ffffff; text-decoration: none; padding: 13px 32px; border-radius: 8px; font-size: 15px; font-weight: 700; display: inline-block;">
            Sign In to PSU E-Ayos &rarr;
          </a>
        </div>

        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="color: #94a3b8; font-size: 12px; margin: 0; text-align: center;">
          This is an automated administrative notification from the Pangasinan State University MMS (E-Ayos).
        </p>
      </div>
        `;
      } else {
        const formattedMsg = (payload.message || '').replace(/\n/g, '<br />');
        htmlBody = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
        <div style="background: linear-gradient(135deg, #1e3a8a, #0284c7); padding: 16px 20px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="color: #ffffff; margin: 0; font-size: 20px; letter-spacing: 0.5px;">PSU Maintenance Management System</h2>
          <p style="color: #bae6fd; margin: 4px 0 0 0; font-size: 13px;">E-Ayos Notification</p>
        </div>
        <h3 style="color: #0f172a; margin-top: 0; font-size: 18px;">${payload.title}</h3>
        <p style="color: #334155; font-size: 15px; line-height: 1.6;">${formattedMsg}</p>
        ${payload.work_request_id ? `<div style="background-color: #f8fafc; border-left: 4px solid #0284c7; padding: 10px 14px; margin: 16px 0; border-radius: 4px;"><span style="color: #64748b; font-size: 13px; font-weight: 600;">Work Request ID:</span> <span style="color: #0f172a; font-size: 13px; font-family: monospace;">${payload.work_request_id}</span></div>` : ''}
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
        <p style="color: #94a3b8; font-size: 12px; margin: 0;">This is an automated notification from PSU E-Ayos.</p>
      </div>
        `;
      }
    }

    // 1. Prioritize Gmail SMTP if configured
    const gmailUser = Deno.env.get('GMAIL_USER') || Deno.env.get('SMTP_USER');
    const gmailPass = Deno.env.get('GMAIL_APP_PASSWORD') || Deno.env.get('SMTP_PASSWORD');

    if (gmailUser && gmailPass) {
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: gmailUser,
          pass: gmailPass,
        },
      });

      const info = await transporter.sendMail({
        from: `"PSU E-Ayos Maintenance" <${gmailUser}>`,
        to: payload.recipient_email,
        subject: payload.subject,
        text: payload.message,
        html: htmlBody,
      });

      console.log(`[send-email] Sent via Gmail to ${payload.recipient_email}: ${info.messageId}`);
      return new Response(
        JSON.stringify({ success: true, provider: 'gmail', messageId: info.messageId }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Fallback to Resend API if configured
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
          from: `PSU E-Ayos <${senderEmail}>`,
          to: [payload.recipient_email],
          subject: payload.subject,
          text: payload.message,
          html: htmlBody,
        }),
      });

      const data = await res.json();
      return new Response(JSON.stringify({ success: true, provider: 'resend', data }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Mock fallback when no credentials are configured
    console.log(`[send-email] Mock dispatch to ${payload.recipient_email}: "${payload.subject}"`);
    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email payload logged (GMAIL_USER or RESEND_API_KEY not configured)',
        recipient: payload.recipient_email,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('send-email error:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
