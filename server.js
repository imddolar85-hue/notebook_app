const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const { AccessToken, TokenVerifier, EgressClient, RoomCompositeEgressRequest, EncodedFileOutput, S3Upload } = require("livekit-server-sdk");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { Resend } = require("resend");
const { S3Client, GetObjectCommand, HeadObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

initializeApp();

const app = express();

app.use(express.json());
app.use(cors());

const db = getFirestore();
const livekitUrl = process.env.LIVEKIT_URL || "https://notebook-hlsctmd9.livekit.cloud";
const b2Client = new S3Client({
  region: process.env.B2_REGION || "us-east-005",
  endpoint: process.env.B2_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: process.env.B2_APPLICATION_KEY_ID,
    secretAccessKey: process.env.B2_APPLICATION_KEY,
  },
});

const egressClient = new EgressClient(
  livekitUrl,
  process.env.LIVEKIT_API_KEY,
  process.env.LIVEKIT_API_SECRET
);

const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_SECONDS = 60;

function hashValue(value) {
  return crypto
    .createHash("sha256")
    .update(value)
    .digest("hex");
}

function generateOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "NoteBook Backend Server is running.",
  });
});

// =========================
// FORGOT PASSWORD - REQUEST OTP
// =========================
app.post("/requestPasswordOtp", async (req, res) => {
  try {
    const email = String(req.body?.email || "")
      .trim()
      .toLowerCase();

    if (!email || !email.includes("@")) {
      return res.status(400).json({
        success: false,
        message: "Please enter a valid email address.",
      });
    }

    const emailHash = hashValue(email);
    const otpRef = db.collection("passwordResetOtps").doc(emailHash);

    const existing = await otpRef.get();

    if (existing.exists) {
      const data = existing.data();

      if (data?.lastSentAt) {
        const lastSent = data.lastSentAt.toDate
          ? data.lastSentAt.toDate()
          : new Date(data.lastSentAt);

        const secondsPassed =
          (Date.now() - lastSent.getTime()) / 1000;

        if (false) {
          return res.status(429).json({
            success: false,
            message:
              "Please wait before requesting another code.",
          });
        }
      }
    }

    let user;

    try {
      user = await getAuth().getUserByEmail(email);
    } catch (error) {
      return res.status(200).json({
        success: true,
        message:
          "If an account exists, a verification code has been sent.",
      });
    }

    const otp = generateOtp();
    const otpHash = hashValue(otp);

    const expiresAt = new Date(
      Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000
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

    const { data, error } = await resend.emails.send({
      from: "Smart Notebook <onboarding@resend.dev>",
      to: [email],
      subject: "Your Smart Notebook Password Reset Code",
      html: `
        <div style="font-family: Arial, sans-serif;">
          <h2>Smart Notebook</h2>
          <p>Your password reset verification code is:</p>
          <h1 style="letter-spacing: 8px;">${otp}</h1>
          <p>This code will expire in 10 minutes.</p>
          <p>If you did not request this code, you can ignore this email.</p>
        </div>
      `,
    });

    if (error) {
      console.error("Resend email error:", error);
      return res.status(500).json({
        success: false,
        message: "Could not send verification code.",
      });
    }

    console.log("Resend email sent:", data?.id);
    return res.status(200).json({
      success: true,
      message:
        "If an account exists, a verification code has been sent.",
    });
  } catch (error) {
    console.error("requestPasswordOtp error:", error);

    return res.status(500).json({
      success: false,
      message: "Could not send verification code.",
    });
  }
});

// =========================
// FORGOT PASSWORD - VERIFY OTP
// =========================
app.post("/verifyPasswordOtp", async (req, res) => {
  try {
    const email = String(req.body?.email || "")
      .trim()
      .toLowerCase();

    const otp = String(req.body?.otp || "").trim();

    if (!email || !/^\d{6}$/.test(otp)) {
      return res.status(400).json({
        success: false,
        message: "Invalid verification code.",
      });
    }

    const emailHash = hashValue(email);
    const otpRef = db.collection("passwordResetOtps").doc(emailHash);

    const snapshot = await otpRef.get();

    if (!snapshot.exists) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired verification code.",
      });
    }

    const data = snapshot.data();

    if (data.verified === true) {
      return res.status(400).json({
        success: false,
        message: "This code has already been used.",
      });
    }

    const expiresAt = data.expiresAt.toDate
      ? data.expiresAt.toDate()
      : new Date(data.expiresAt);

    if (expiresAt < new Date()) {
      return res.status(400).json({
        success: false,
        message: "This verification code has expired.",
      });
    }

    if ((data.attempts || 0) >= MAX_ATTEMPTS) {
      return res.status(429).json({
        success: false,
        message:
          "Too many incorrect attempts. Please request a new code.",
      });
    }

    const submittedHash = hashValue(otp);

    if (submittedHash !== data.otpHash) {
      await otpRef.update({
        attempts: (data.attempts || 0) + 1,
      });

      return res.status(400).json({
        success: false,
        message: "Incorrect verification code.",
      });
    }

    const resetToken = crypto.randomBytes(32).toString("hex");

    await otpRef.update({
      verified: true,
      resetTokenHash: hashValue(resetToken),
      resetTokenExpiresAt: new Date(Date.now() + 10 * 60 * 1000),
    });

    return res.status(200).json({
      success: true,
      resetToken: resetToken,
    });
  } catch (error) {
    console.error("verifyPasswordOtp error:", error);

    return res.status(500).json({
      success: false,
      message: "Verification failed.",
    });
  }
});

// =========================
// FORGOT PASSWORD - RESET
// =========================
app.post("/resetPassword", async (req, res) => {
  try {
    const email = String(req.body?.email || "")
      .trim()
      .toLowerCase();

    const resetToken = String(
      req.body?.resetToken || ""
    ).trim();

    const newPassword = String(
      req.body?.newPassword || ""
    );

    if (!email || !resetToken || newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Invalid reset request or password.",
      });
    }

    const emailHash = hashValue(email);
    const otpRef = db.collection("passwordResetOtps").doc(emailHash);

    const snapshot = await otpRef.get();

    if (!snapshot.exists) {
      return res.status(400).json({
        success: false,
        message: "Invalid password reset request.",
      });
    }

    const data = snapshot.data();

    if (data.verified !== true) {
      return res.status(400).json({
        success: false,
        message: "Verification required.",
      });
    }

    const resetTokenExpiresAt = data.resetTokenExpiresAt
      ? (
          data.resetTokenExpiresAt.toDate
            ? data.resetTokenExpiresAt.toDate()
            : new Date(data.resetTokenExpiresAt)
        )
      : null;

    if (
      !resetTokenExpiresAt ||
      resetTokenExpiresAt < new Date()
    ) {
      return res.status(400).json({
        success: false,
        message: "Reset session has expired.",
      });
    }

    const tokenHash = hashValue(resetToken);

    if (tokenHash !== data.resetTokenHash) {
      return res.status(400).json({
        success: false,
        message: "Invalid password reset request.",
      });
    }

    await getAuth().getUser(data.uid);

    await getAuth().updateUser(data.uid, {
      password: newPassword,
    });

    await otpRef.delete();

    return res.status(200).json({
      success: true,
      message: "Password has been reset successfully.",
    });
  } catch (error) {
    console.error("resetPassword error:", error);

    return res.status(500).json({
      success: false,
      message: "Could not reset password.",
    });
  }
});

// =========================
// LIVEKIT TOKEN
// =========================
app.post("/createLiveKitToken", async (req, res) => {
  try {
    const roomName = String(
      req.body?.roomName || ""
    ).trim();

    const participantName = String(
      req.body?.participantName || ""
    ).trim();

    if (!roomName || !participantName) {
      return res.status(400).json({
        success: false,
        message:
          "Room name and participant name are required.",
      });
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;

    if (!apiKey || !apiSecret) {
      return res.status(500).json({
        success: false,
        message: "LiveKit configuration is missing.",
      });
    }

    const token = new AccessToken(
      apiKey,
      apiSecret,
      {
        identity: participantName,
        name: participantName,
        ttl: "1h",
      }
    );

    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
    });

    const jwt = await token.toJwt();

    return res.status(200).json({
      success: true,
      token: jwt,
    });
  } catch (error) {
    console.error("createLiveKitToken error:", error);

    return res.status(500).json({
      success: false,
      message: "Could not create LiveKit token.",
    });
  }
});

// =========================
// LIVEKIT TOKEN VERIFICATION
// =========================
app.post("/verifyLiveKitToken", async (req, res) => {
  try {
    const token = String(
      req.body?.token || ""
    ).trim();

    if (!token) {
      return res.status(400).json({
        success: false,
        message: "Token is required.",
      });
    }

    const verifier = new TokenVerifier(
      process.env.LIVEKIT_API_KEY,
      process.env.LIVEKIT_API_SECRET
    );

    const result = await verifier.verify(token);

    return res.status(200).json({
      success: true,
      identity: result.identity,
      name: result.name,
    });
  } catch (error) {
    console.error("verifyLiveKitToken error:", error);

    return res.status(401).json({
      success: false,
      message:
        error.message || "Token verification failed.",
    });
  }
});

const PORT = Number(process.env.PORT) || 10000;

app.post("/startLiveRecording", async (req, res) => {
  try {
    const roomName = String(req.body?.roomName || "").trim();

    if (!roomName) {
      return res.status(400).json({
        success: false,
        message: "roomName is required.",
      });
    }

    const accessKey = process.env.B2_APPLICATION_KEY_ID;
    const secret = process.env.B2_APPLICATION_KEY;
    const bucket = process.env.B2_BUCKET_NAME;
    const endpoint = process.env.B2_ENDPOINT;
    const region = "us-east-005";

    if (!accessKey || !secret || !bucket || !endpoint) {
      return res.status(500).json({
        success: false,
        message: "B2 storage configuration is missing.",
      });
    }

    const filepath = `live-recordings/${roomName}-${Date.now()}.mp4`;

    const fileOutput = new EncodedFileOutput({
      fileType: 1,
      filepath,
      output: {
        case: "s3",
        value: new S3Upload({
          accessKey,
          secret,
          region,
          endpoint,
          bucket,
          forcePathStyle: true,
        }),
      },
    });

    const info = await egressClient.startRoomCompositeEgress(
      roomName,
      fileOutput,
      {
        layout: "grid",
      }
    );

    return res.status(200).json({
      success: true,
      egressId: info.egressId,
      roomName,
      filepath,
    });
  } catch (error) {
    console.error("startLiveRecording error:", error);
    return res.status(500).json({
      success: false,
      message: "Could not start live recording.",
    });
  }
});
app.post("/stopLiveRecording", async (req, res) => {
  try {
    const egressId = String(req.body?.egressId || "").trim();
    const requestedVideoKey = String(req.body?.videoKey || "").trim();


    if (!egressId) {
      return res.status(100).json( {
        success: false,
        message: "egressId is required.",
      });
    }

    await egressClient.stopEgress(egressId);

    const terminalStatuses = new Set([3, 4, 5, 6]);
    let finalInfo = null;


    for (let attempt = 0; attempt < 90; attempt++) {
      const results = await egressClient.listEgress({ egressId });
      finalInfo = results?.[0] ?? null;


      if (finalInfo && terminalStatuses.has(Number(finalInfo.status))) {
        break;
      }

      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    if (!finalInfo) {
      return res.status(404).json({
        success: false,
        message: "Egress recording was not found after stop request.",
      });
    }

    const status = Number(finalInfo.status);

    if (status !== 3) {
      return res.status(409).json({
        success: false,
        ready: false,
        egressId,
        status,
        error: finalInfo.error || finalInfo.details || "Recording did not complete successfully.",
      });
    }

    const fileInfo = finalInfo.fileResults?.[0] ?? null;
    const filename = String(fileInfo?.filename || "").trim();
    const location = String(fileInfo?.location || "").trim();

    let videoKey = requestedVideoKey || filename;

    if (!videoKey && location) {
      const marker = "live-recordings/";
      const markerIndex = location.indexOf(marker);
      if (markerIndex >= 0) {
        videoKey = location.substring(markerIndex);
      }
    }

    if (!videoKey || !videoKey.startsWith("live-recordings/")) {
      return res.status(500).json({
        success: false,
        ready: false,
        egressId,
        status,
        message: "Recording completed, but the final video key could not be determined.",
        filename: filename || null,
        location: location || null,
      });
    }

    const bucket = process.env.B2_BUCKET_NAME;

    if (!bucket) {
      return res.status(500).json({
        success: false,
        ready: false,
        egressId,
        status,
        message: "B2 bucket is not configured.",
      });
    }

    await b2Client.send(
      new HeadObjectCommand({
        Bucket: bucket,
        Key: videoKey,
      }),
    );

    return res.status(200).json({
      success: true,
      ready: true,
      egressId,
      status,
      videoKey,
      filename: filename || null,
      location: location || null,
    });
  } catch (error) {
    console.error("stopLiveRecording error:", error);

    return res.status(500).json({
      success: false,
      ready: false,
      message: "Could not stop live recording.",
    });
  }
});app.post("/createVideoPlaybackUrl", async (req, res) => {
  try {
    const videoKey = String(req.body?.videoKey || "").trim();

    if (!videoKey) {
      return res.status(400).json({
        success: false,
        message: "videoKey is required.",
      });
    }

    if (!videoKey.startsWith("live-recordings/")) {
      return res.status(400).json({
        success: false,
        message: "Invalid video key.",
      });
    }

    const bucket = process.env.B2_BUCKET_NAME;

    if (!bucket) {
      return res.status(500).json({
        success: false,
        message: "B2 bucket is not configured.",
      });
    }

    await b2Client.send(
      new HeadObjectCommand({
        Bucket: bucket,
        Key: videoKey,
      })
    );

    const command = new GetObjectCommand({
      Bucket: bucket,
      Key: videoKey,
    });

    const url = await getSignedUrl(b2Client, command, {
      expiresIn: 3600,
    });

    return res.status(200).json({
      success: true,
      url,
      expiresIn: 3600,
    });
  } catch (error) {
    console.error("createVideoPlaybackUrl error:", error);

    return res.status(500).json({
      success: false,
      message: "Could not create video playback URL.",
    });
  }
});
app.get("/checkB2", (req, res) => {
  return res.status(200).json({
    success: true,
    B2_APPLICATION_KEY_ID: process.env.B2_APPLICATION_KEY_ID ? "SET" : "NOT SET",
    B2_APPLICATION_KEY: process.env.B2_APPLICATION_KEY ? "SET" : "NOT SET",
    B2_BUCKET_NAME: process.env.B2_BUCKET_NAME ? "SET" : "NOT SET",
    B2_ENDPOINT: process.env.B2_ENDPOINT ? "SET" : "NOT SET",
  });
});
app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `NoteBook Backend Server running on port ${PORT}`
  );
});



















