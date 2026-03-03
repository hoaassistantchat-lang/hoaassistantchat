package com.hoa.assistant.service;

import com.hoa.assistant.model.Ticket;
import com.hoa.assistant.model.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;

/**
 * EmailService handles all outbound email notifications.
 *
 * Supports SendGrid (SMTP relay) and AWS SES (SMTP endpoint).
 * Configure via environment variables:
 *   MAIL_ENABLED=true
 *   MAIL_HOST=smtp.sendgrid.net  (or email-smtp.us-east-1.amazonaws.com)
 *   MAIL_PORT=587
 *   MAIL_USERNAME=apikey          (SendGrid) or IAM access key (SES)
 *   MAIL_PASSWORD=<key>
 *   MAIL_FROM=noreply@yourdomain.com
 *   APP_BASE_URL=https://yourdomain.com
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${hoa.email.enabled:false}")
    private boolean emailEnabled;

    @Value("${hoa.email.from-address:noreply@hoa-assistant.com}")
    private String fromAddress;

    @Value("${hoa.email.from-name:HOA Assistant}")
    private String fromName;

    @Value("${hoa.email.app-base-url:http://localhost:8080}")
    private String appBaseUrl;

    // --------------------------------------------------------
    // Welcome Email (sent on resident registration)
    // --------------------------------------------------------
    public void sendWelcomeEmail(User user, String communityName) {
        if (!emailEnabled) {
            log.info("[EMAIL SKIP] Welcome email to {}", user.getEmail());
            return;
        }
        String subject = "Welcome to " + communityName + " HOA Assistant!";
        String body = buildWelcomeBody(user, communityName);
        send(user.getEmail(), subject, body);
    }

    // --------------------------------------------------------
    // Password Reset Email
    // --------------------------------------------------------
    public void sendPasswordResetEmail(User user, String token, String communityName) {
        if (!emailEnabled) {
            log.info("[EMAIL SKIP] Password reset email to {}", user.getEmail());
            return;
        }
        String resetUrl = appBaseUrl + "/index.html#reset?token=" + token;
        String subject = communityName + " – Password Reset Request";
        String body = buildPasswordResetBody(user, resetUrl, communityName);
        send(user.getEmail(), subject, body);
    }

    // --------------------------------------------------------
    // Ticket Created Email (sent to admin + optionally resident)
    // --------------------------------------------------------
    public void sendTicketCreatedEmail(Ticket ticket, String residentEmail, String communityName) {
        if (!emailEnabled) {
            log.info("[EMAIL SKIP] Ticket created email for ticket #{}", ticket.getId());
            return;
        }
        String subject = communityName + " – New Ticket #" + ticket.getId() + " Submitted";
        String body = buildTicketCreatedBody(ticket, communityName);
        if (residentEmail != null && !residentEmail.isBlank()) {
            send(residentEmail, subject, body);
        }
    }

    // --------------------------------------------------------
    // Ticket Updated Email (sent when status changes)
    // --------------------------------------------------------
    public void sendTicketUpdatedEmail(Ticket ticket, String residentEmail, String communityName) {
        if (!emailEnabled) {
            log.info("[EMAIL SKIP] Ticket updated email for ticket #{}", ticket.getId());
            return;
        }
        String subject = communityName + " – Ticket #" + ticket.getId() + " Status Updated";
        String body = buildTicketUpdatedBody(ticket, communityName);
        if (residentEmail != null && !residentEmail.isBlank()) {
            send(residentEmail, subject, body);
        }
    }

    // --------------------------------------------------------
    // Internal send helper
    // --------------------------------------------------------
    private void send(String to, String subject, String htmlBody) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromAddress, fromName);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(htmlBody, true);
            mailSender.send(message);
            log.info("Email sent to {} | subject: {}", to, subject);
        } catch (MailException | MessagingException | java.io.UnsupportedEncodingException e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
            // Don't throw — email failure should never break the main flow
        }
    }

    // --------------------------------------------------------
    // HTML Body Builders
    // --------------------------------------------------------
    private String buildWelcomeBody(User user, String communityName) {
        String name = user.getFirstName() != null ? user.getFirstName() : user.getEmail();
        return """
            <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;">
              <div style="background:#2563eb;color:#fff;padding:20px;border-radius:8px 8px 0 0;text-align:center;">
                <h1 style="margin:0;font-size:24px;">🏘️ %s</h1>
                <p style="margin:5px 0 0;opacity:.85;">HOA Assistant</p>
              </div>
              <div style="background:#fff;border:1px solid #e2e8f0;border-top:none;padding:30px;border-radius:0 0 8px 8px;">
                <h2 style="color:#1e293b;">Welcome, %s!</h2>
                <p style="color:#475569;line-height:1.6;">
                  Your account has been created for the <strong>%s</strong> community.
                  You can now log in to chat with the AI assistant, check HOA rules, submit maintenance requests,
                  and much more.
                </p>
                <div style="text-align:center;margin:30px 0;">
                  <a href="%s" style="background:#2563eb;color:#fff;padding:12px 28px;border-radius:6px;
                     text-decoration:none;font-weight:bold;display:inline-block;">
                    Open HOA Assistant
                  </a>
                </div>
                <p style="color:#64748b;font-size:13px;">
                  If you have any questions, reply to this email or contact your HOA administrator.
                </p>
              </div>
              <p style="text-align:center;color:#94a3b8;font-size:12px;margin-top:16px;">
                © HOA Assistant &middot; Unsubscribe
              </p>
            </div>
            """.formatted(communityName, name, communityName, appBaseUrl);
    }

    private String buildPasswordResetBody(User user, String resetUrl, String communityName) {
        String name = user.getFirstName() != null ? user.getFirstName() : user.getEmail();
        return """
            <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;">
              <div style="background:#2563eb;color:#fff;padding:20px;border-radius:8px 8px 0 0;text-align:center;">
                <h1 style="margin:0;font-size:24px;">🏘️ %s</h1>
              </div>
              <div style="background:#fff;border:1px solid #e2e8f0;border-top:none;padding:30px;border-radius:0 0 8px 8px;">
                <h2 style="color:#1e293b;">Password Reset Request</h2>
                <p style="color:#475569;line-height:1.6;">Hi %s,</p>
                <p style="color:#475569;line-height:1.6;">
                  We received a request to reset your password. Click the button below to set a new password.
                  This link will expire in <strong>2 hours</strong>.
                </p>
                <div style="text-align:center;margin:30px 0;">
                  <a href="%s" style="background:#dc2626;color:#fff;padding:12px 28px;border-radius:6px;
                     text-decoration:none;font-weight:bold;display:inline-block;">
                    Reset My Password
                  </a>
                </div>
                <p style="color:#64748b;font-size:13px;">
                  If you didn't request a password reset, you can safely ignore this email.
                  Your password will not change.
                </p>
              </div>
            </div>
            """.formatted(communityName, name, resetUrl);
    }

    private String buildTicketCreatedBody(Ticket ticket, String communityName) {
        return """
            <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;">
              <div style="background:#2563eb;color:#fff;padding:20px;border-radius:8px 8px 0 0;text-align:center;">
                <h1 style="margin:0;font-size:24px;">🏘️ %s</h1>
              </div>
              <div style="background:#fff;border:1px solid #e2e8f0;border-top:none;padding:30px;border-radius:0 0 8px 8px;">
                <h2 style="color:#1e293b;">✅ Ticket #%d Received</h2>
                <p style="color:#475569;line-height:1.6;">
                  Your maintenance request has been received and will be reviewed by the HOA team.
                </p>
                <table style="width:100%%;border-collapse:collapse;margin:20px 0;">
                  <tr><td style="padding:8px;background:#f8fafc;font-weight:bold;width:35%%;border:1px solid #e2e8f0;">Type</td>
                      <td style="padding:8px;border:1px solid #e2e8f0;">%s</td></tr>
                  <tr><td style="padding:8px;background:#f8fafc;font-weight:bold;border:1px solid #e2e8f0;">Priority</td>
                      <td style="padding:8px;border:1px solid #e2e8f0;">%s</td></tr>
                  <tr><td style="padding:8px;background:#f8fafc;font-weight:bold;border:1px solid #e2e8f0;">Description</td>
                      <td style="padding:8px;border:1px solid #e2e8f0;">%s</td></tr>
                  <tr><td style="padding:8px;background:#f8fafc;font-weight:bold;border:1px solid #e2e8f0;">Status</td>
                      <td style="padding:8px;border:1px solid #e2e8f0;color:#d97706;">Open</td></tr>
                </table>
                <p style="color:#64748b;font-size:13px;">
                  You will receive another email when your ticket status is updated.
                </p>
              </div>
            </div>
            """.formatted(
                communityName,
                ticket.getId(),
                ticket.getTicketType(),
                ticket.getPriority(),
                ticket.getDescription()
        );
    }

    private String buildTicketUpdatedBody(Ticket ticket, String communityName) {
        String statusColor = switch (ticket.getStatus()) {
            case "resolved", "closed" -> "#16a34a";
            case "in_progress"        -> "#2563eb";
            default                   -> "#d97706";
        };
        return """
            <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;">
              <div style="background:#2563eb;color:#fff;padding:20px;border-radius:8px 8px 0 0;text-align:center;">
                <h1 style="margin:0;font-size:24px;">🏘️ %s</h1>
              </div>
              <div style="background:#fff;border:1px solid #e2e8f0;border-top:none;padding:30px;border-radius:0 0 8px 8px;">
                <h2 style="color:#1e293b;">🔄 Ticket #%d Status Updated</h2>
                <p style="color:#475569;line-height:1.6;">
                  The status of your ticket has been updated.
                </p>
                <table style="width:100%%;border-collapse:collapse;margin:20px 0;">
                  <tr><td style="padding:8px;background:#f8fafc;font-weight:bold;width:35%%;border:1px solid #e2e8f0;">Type</td>
                      <td style="padding:8px;border:1px solid #e2e8f0;">%s</td></tr>
                  <tr><td style="padding:8px;background:#f8fafc;font-weight:bold;border:1px solid #e2e8f0;">New Status</td>
                      <td style="padding:8px;border:1px solid #e2e8f0;font-weight:bold;color:%s;">%s</td></tr>
                </table>
              </div>
            </div>
            """.formatted(
                communityName,
                ticket.getId(),
                ticket.getTicketType(),
                statusColor,
                ticket.getStatus().replace("_", " ").toUpperCase()
        );
    }
}
