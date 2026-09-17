const express = require("express");
const cors = require("cors");
const { AccessToken } = require("livekit-server-sdk");

const app = express();

app.use(express.json());
app.use(cors());

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "NoteBook LiveKit Token Server is running.",
  });
});

app.post("/createLiveKitToken", async (req, res) => {
  try {
    const roomName = String(req.body?.roomName || "").trim();
    const participantName = String(
      req.body?.participantName || ""
    ).trim();

    if (!roomName || !participantName) {
      return res.status(400).json({
        success: false,
        message: "Room name and participant name are required.",
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

const PORT = Number(process.env.PORT) || 10000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`NoteBook LiveKit Token Server running on port ${PORT}`);
});