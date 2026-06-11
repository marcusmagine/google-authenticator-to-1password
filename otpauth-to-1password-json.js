#!/usr/bin/env node

"use strict";

const mode = process.argv[2] || "item";
const importTag = process.env.IMPORT_TAG || "google-authenticator-import";
let input = "";

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  input += chunk;
});
process.stdin.on("end", () => {
  try {
    const otpUrl = input.trim();
    const parsed = new URL(otpUrl);

    if (parsed.protocol !== "otpauth:" || !["totp", "hotp"].includes(parsed.hostname)) {
      throw new Error("input is not a supported otpauth URL");
    }

    const label = decodeURIComponent(parsed.pathname.replace(/^\/+/, ""));
    const issuer = parsed.searchParams.get("issuer") || "";
    let username = label;

    if (issuer && label.startsWith(`${issuer}:`)) {
      username = label.slice(issuer.length + 1);
    } else if (label.includes(":")) {
      username = label.slice(label.indexOf(":") + 1);
    }

    const title = issuer ? `${issuer} (${username})` : label;

    if (mode === "metadata") {
      process.stdout.write(JSON.stringify({ title, issuer, username }));
      return;
    }

    const item = {
      title,
      category: "LOGIN",
      tags: [importTag],
      fields: [
        {
          id: "username",
          type: "STRING",
          purpose: "USERNAME",
          label: "username",
          value: username,
        },
        {
          id: "password",
          type: "CONCEALED",
          purpose: "PASSWORD",
          label: "password",
          value: "",
        },
        {
          id: "otp",
          type: "OTP",
          label: "one-time password",
          value: otpUrl,
        },
        {
          id: "notesPlain",
          type: "STRING",
          purpose: "NOTES",
          label: "notesPlain",
          value: "Imported from Google Authenticator. Verify before removing the original entry.",
        },
      ],
    };

    process.stdout.write(JSON.stringify(item));
  } catch (error) {
    process.stderr.write(`Error: ${error.message}\n`);
    process.exitCode = 1;
  }
});
