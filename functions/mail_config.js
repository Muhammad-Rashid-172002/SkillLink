/* eslint-disable max-len */
/**
 * Sender configuration for SkillNova's own emails (verification and
 * password reset). Pure helpers so they are unit tested without SMTP.
 *
 * Gmail / Google Workspace SMTP only sends "From" the mailbox that logged in
 * (or a "Send mail as" alias already verified on that mailbox). Any other
 * From address is silently rewritten by Gmail to the login mailbox, so the
 * sender address is never assumed to be different from the SMTP login.
 */

const DEFAULT_SENDER = "muhammadrashid172002@gmail.com";
const DEFAULT_SENDER_NAME = "SkillNova";
const EMAIL_PATTERN = /^[^\s@<>"]+@[^\s@<>"]+\.[^\s@<>"]+$/;

/**
 * @param {*} value Candidate address.
 * @return {string} Lower-cased, trimmed address ("" when empty).
 */
function normalizeAddress(value) {
  return String(value || "").trim().toLowerCase();
}

/**
 * Builds the Nodemailer transport options and the From header.
 *
 * @param {Object} config Settings.
 * @param {string} [config.smtpUser] Mailbox that logs in to SMTP.
 * @param {string} [config.fromAddress] Address shown as the sender.
 * @param {string} [config.fromName] Display name.
 * @param {string} [config.password] App Password (from Secret Manager).
 * @param {string} [config.host] SMTP host (smtp.gmail.com).
 * @param {number|string} [config.port] SMTP port (465).
 * @param {Array<string>} [config.aliases] Verified "Send mail as" aliases of smtpUser.
 * @return {{transport: Object, from: string, fromAddress: string, smtpUser: string}} Mail settings.
 */
function buildMailSettings(config = {}) {
  const smtpUser = normalizeAddress(config.smtpUser) || DEFAULT_SENDER;
  const fromAddress = normalizeAddress(config.fromAddress) || smtpUser;
  const fromName = String(config.fromName || DEFAULT_SENDER_NAME).replace(/["<>\r\n]/g, "").trim() || DEFAULT_SENDER_NAME;
  const aliases = (config.aliases || []).map(normalizeAddress).filter(Boolean);

  for (const [label, value] of [["SMTP user", smtpUser], ["sender", fromAddress]]) {
    if (!EMAIL_PATTERN.test(value)) throw new Error(`Invalid ${label} email address.`);
  }
  if (fromAddress !== smtpUser && !aliases.includes(fromAddress)) {
    // Gmail would rewrite the From header to smtpUser; refuse rather than
    // send mail that looks like it came from someone else.
    throw new Error("The sender must be the SMTP mailbox or a verified Send-mail-as alias of it.");
  }
  if (!config.password) throw new Error("SMTP password is not configured.");

  const port = Number(config.port || 465);
  return {
    smtpUser,
    fromAddress,
    from: `"${fromName}" <${fromAddress}>`,
    transport: {
      host: String(config.host || "smtp.gmail.com"),
      port,
      secure: port === 465,
      auth: {user: smtpUser, pass: config.password},
    },
  };
}

module.exports = {DEFAULT_SENDER, buildMailSettings, normalizeAddress};
