/* eslint-disable max-len */
const test = require("node:test");
const assert = require("node:assert/strict");
const m = require("../mail_config");

test("default sender is the SkillNova support Gmail and matches the SMTP login", () => {
  const s = m.buildMailSettings({password: "app-password"});
  assert.equal(m.DEFAULT_SENDER, "muhammadrashid172002@gmail.com");
  assert.equal(s.from, "\"SkillNova\" <muhammadrashid172002@gmail.com>");
  assert.equal(s.transport.auth.user, "muhammadrashid172002@gmail.com");
  assert.equal(s.transport.host, "smtp.gmail.com");
  assert.equal(s.transport.port, 465);
  assert.equal(s.transport.secure, true);
});

test("addresses are normalised; the old Workspace sender is gone", () => {
  const s = m.buildMailSettings({smtpUser: " MuhammadRashid172002@Gmail.com ", fromAddress: "MUHAMMADRASHID172002@gmail.com", password: "x"});
  assert.equal(s.fromAddress, "muhammadrashid172002@gmail.com");
  assert.ok(!s.from.includes("korvenzatech"));
});

test("a From address Gmail would rewrite is refused", () => {
  assert.throws(() => m.buildMailSettings({smtpUser: "ceo@korvenzatech.com", fromAddress: "muhammadrashid172002@gmail.com", password: "x"}), /Send-mail-as alias/);
  // Allowed only when it is a verified alias of the SMTP mailbox.
  const s = m.buildMailSettings({smtpUser: "ceo@korvenzatech.com", fromAddress: "muhammadrashid172002@gmail.com", aliases: ["muhammadrashid172002@gmail.com"], password: "x"});
  assert.equal(s.transport.auth.user, "ceo@korvenzatech.com");
});

test("missing password and malformed addresses fail before any send", () => {
  assert.throws(() => m.buildMailSettings({}), /password/);
  assert.throws(() => m.buildMailSettings({smtpUser: "not-an-email", password: "x"}), /Invalid SMTP user/);
  assert.throws(() => m.buildMailSettings({fromAddress: "a@b", password: "x"}), /Invalid sender|alias/);
});

test("display name cannot inject headers", () => {
  const s = m.buildMailSettings({fromName: "Skill\"Nova\r\nBcc: x@y.z", password: "x"});
  assert.equal(s.from, "\"SkillNovaBcc: x@y.z\" <muhammadrashid172002@gmail.com>");
  assert.ok(!/[\r\n]/.test(s.from));
});

test("a local SMTP catcher can be used for emulator tests", () => {
  const s = m.buildMailSettings({host: "127.0.0.1", port: "1025", password: "x"});
  assert.equal(s.transport.port, 1025);
  assert.equal(s.transport.secure, false);
});
