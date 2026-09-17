const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const crypto = require("crypto");
const {Resend} = require("resend");
const {AccessToken} = require("livekit-server-sdk");
initializeApp();

setGlobalOptions({
  maxInstances: 10,
});

const db = getFirestore();

const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_SECONDS = 60;

/**
 * Returns a SHA-256 hash for the given value.
 * @param {string} value The value to hash.
 * @return {string} The SHA-256 hash.
 */
function hashValue(value) {
  return crypto
      .createHash("sha256")
      .update(value)
      .digest("hex");
}

/**
 * Generates a six-digit OTP.
 * @return {string} A six-digit OTP.
 */
function generateOtp() {
  return crypto
      .randomInt(100000, 1000000)
      .toString();
}

exports.requestPasswordOtp = onRequest(
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({
          success: false,
          message: "Method not allowed.",
        });
        return;
      }

      try {
        const email = String(req.body?.email || "")
            .trim()
            .toLowerCase();

        if (!email || !email.includes("@")) {
          res.status(400).json({
            success: false,
            message: "Please enter a valid email address.",
          });
          return;
        }

        const emailHash = hashValue(email);
        const otpRef = db
            .collection("passwordResetOtps")
            .doc(emailHash);

        const existing = await otpRef.get();

        if (existing.exists) {
          const data = existing.data();

          if (data?.lastSentAt) {
            const lastSent = data.lastSentAt.toMillis();
            const secondsPassed =
                (Date.now() - lastSent) / 1000;

            if (secondsPassed < RESEND_COOLDOWN_SECONDS) {
              res.status(429).json({
                success: false,
                message:
                    "Please wait before requesting another code.",
              });
              return;
            }
          }
        }

        let user;

        try {
          user = await getAuth().getUserByEmail(email);
        } catch (error) {
          // Do not reveal whether an email exists.
          res.status(200).json({
            success: true,
            message:
                "If an account exists, a verification code has been sent.",
          });
          return;
        }

        const otp = generateOtp();
        const otpHash = hashValue(otp);

        const expiresAt = new Date(
            Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000,
        );

        await otpRef.set({
          uid: user.uid,
          email: email,
          otpHash: otpHash,
          expiresAt: expiresAt,
          attempts: 0,
          verified: false,
          lastSentAt: new Date(),
          createdAt: new Date(),
        });

        const resend = new Resend(process.env.RESEND_API_KEY);

        await resend.emails.send({
          from: "Smart Notebook <onboarding@resend.dev>",
          to: [email],
          subject: "Your Smart Notebook Password Reset Code",
          html: `
            <div style="font-family: Arial, sans-serif;">
              <h2>Smart Notebook</h2>
              <p>Your password reset verification code is:</p>
              <h1 style="letter-spacing: 8px;">${otp}</h1>
              <p>This code will expire in 10 minutes.</p>
              <p>If you did not request this code,</p>
              <p>You can ignore this email.</p>
            </div>
          `,
        });

        res.status(200).json({
          success: true,
          message:
              "If an account exists, a verification code has been sent.",
        });
      } catch (error) {
        console.error("requestPasswordOtp error:", error);

        res.status(500).json({
          success: false,
          message: "Could not send verification code.",
        });
      }
    },
);

exports.verifyPasswordOtp = onRequest(
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({
          success: false,
          message: "Method not allowed.",
        });
        return;
      }

      try {
        const email = String(req.body?.email || "")
            .trim()
            .toLowerCase();

        const otp = String(req.body?.otp || "").trim();

        if (!email || !/^\d{6}$/.test(otp)) {
          res.status(400).json({
            success: false,
            message: "Invalid verification code.",
          });
          return;
        }

        const emailHash = hashValue(email);

        const otpRef = db
            .collection("passwordResetOtps")
            .doc(emailHash);

        const snapshot = await otpRef.get();

        if (!snapshot.exists) {
          res.status(400).json({
            success: false,
            message: "Invalid or expired verification code.",
          });
          return;
        }

        const data = snapshot.data();

        if (data.verified === true) {
          res.status(400).json({
            success: false,
            message: "This code has already been used.",
          });
          return;
        }

        if (data.expiresAt.toDate() < new Date()) {
          res.status(400).json({
            success: false,
            message: "This verification code has expired.",
          });
          return;
        }

        if ((data.attempts || 0) >= MAX_ATTEMPTS) {
          res.status(429).json({
            success: false,
            message:
                "Too many incorrect attempts. Please request a new code.",
          });
          return;
        }

        const submittedHash = hashValue(otp);

        if (submittedHash !== data.otpHash) {
          await otpRef.update({
            attempts: (data.attempts || 0) + 1,
          });

          res.status(400).json({
            success: false,
            message: "Incorrect verification code.",
          });
          return;
        }

        const resetToken = crypto.randomBytes(32).toString("hex");

        await otpRef.update({
          verified: true,
          resetTokenHash: hashValue(resetToken),
          resetTokenExpiresAt: new Date(
              Date.now() + 10 * 60 * 1000,
          ),
        });

        res.status(200).json({
          success: true,
          resetToken: resetToken,
        });
      } catch (error) {
        console.error("verifyPasswordOtp error:", error);

        res.status(500).json({
          success: false,
          message: "Verification failed.",
        });
      }
    },
);

exports.resetPassword = onRequest(
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({
          success: false,
          message: "Method not allowed.",
        });
        return;
      }

      try {
        const email = String(req.body?.email || "")
            .trim()
            .toLowerCase();

        const resetToken =
            String(req.body?.resetToken || "").trim();

        const newPassword =
            String(req.body?.newPassword || "");

        if (!email || !resetToken || newPassword.length < 6) {
          res.status(400).json({
            success: false,
            message:
                "Invalid reset request or password.",
          });
          return;
        }

        const emailHash = hashValue(email);

        const otpRef = db
            .collection("passwordResetOtps")
            .doc(emailHash);

        const snapshot = await otpRef.get();

        if (!snapshot.exists) {
          res.status(400).json({
            success: false,
            message: "Invalid password reset request.",
          });
          return;
        }

        const data = snapshot.data();

        if (data.verified !== true) {
          res.status(400).json({
            success: false,
            message: "Verification required.",
          });
          return;
        }

        if (
          !data.resetTokenExpiresAt ||
          data.resetTokenExpiresAt.toDate() < new Date()
        ) {
          res.status(400).json({
            success: false,
            message: "Reset session has expired.",
          });
          return;
        }

        const tokenHash = hashValue(resetToken);

        if (tokenHash !== data.resetTokenHash) {
          res.status(400).json({
            success: false,
            message: "Invalid password reset request.",
          });
          return;
        }

        const authUser = await getAuth().getUser(data.uid);

        console.log(
            "RESET USER:",
            authUser.uid,
            authUser.email,
            authUser.providerData,
        );

        await getAuth().updateUser(data.uid, {
          password: newPassword,
        });

        await otpRef.delete();
        res.status(200).json({
          success: true,
          message: "Password has been reset successfully.",
        });
      } catch (error) {
        console.error("resetPassword error:", error);

        res.status(500).json({
          success: false,
          message: "Could not reset password.",
        });
      }
    },
);

// =========================
// LIVEKIT TOKEN
// =========================
exports.createLiveKitToken = onRequest(
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({
          success: false,
          message: "Method not allowed.",
        });
        return;
      }

      try {
        const roomName = String(req.body?.roomName || "").trim();
        const participantName =
            String(req.body?.participantName || "").trim();

        if (!roomName || !participantName) {
          res.status(400).json({
            success: false,
            message: "Room name and participant name are required.",
          });
          return;
        }

        const apiKey = process.env.LIVEKIT_API_KEY;
        const apiSecret = process.env.LIVEKIT_API_SECRET;

        if (!apiKey || !apiSecret) {
          console.error("LiveKit credentials are missing.");
          res.status(500).json({
            success: false,
            message: "LiveKit configuration is missing.",
          });
          return;
        }

        const token = new AccessToken(apiKey, apiSecret, {
          identity: participantName,
          name: participantName,
          ttl: "1h",
        });

        token.addGrant({
          roomJoin: true,
          room: roomName,
          canPublish: true,
          canSubscribe: true,
        });

        const jwt = await token.toJwt();

        res.status(200).json({
          success: true,
          token: jwt,
        });
      } catch (error) {
        console.error("createLiveKitToken error:", error);

        res.status(500).json({
          success: false,
          message: "Could not create LiveKit token.",
        });
      }
    },
);
