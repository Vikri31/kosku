import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Top-level function handler tanpa middleware withSupabase
// Agar bisa dipanggil oleh Database Webhook tanpa masalah autentikasi
Deno.serve(async (req: Request) => {
  try {
    // 1. Parse payload dari Request
    const payload = await req.json();

    // Mendukung pemanggilan direct maupun Supabase Database Webhook
    // Webhook mengirim data dalam format: { type, table, record, ... }
    let id_user: string | undefined;
    let title: string | undefined;
    let body: string | undefined;

    if (payload.record) {
      // Dipanggil oleh Database Webhook (INSERT ke tabel notifikasi)
      id_user = payload.record.id_user;
      title = payload.record.judul || payload.record.title;
      body = payload.record.pesan || payload.record.body;
    } else {
      // Dipanggil secara langsung (manual / curl)
      id_user = payload.id_user;
      title = payload.title || payload.judul;
      body = payload.body || payload.pesan;
    }

    if (!id_user || !title || !body) {
      return new Response(
        JSON.stringify({
          error: "Parameter 'id_user', 'title/judul', dan 'body/pesan' wajib disertakan.",
          received: { id_user, title, body, payload_keys: Object.keys(payload) },
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[INFO] Memproses notifikasi untuk user: ${id_user}, judul: ${title}`);

    // 2. Buat Supabase Admin Client secara manual
    // Menggunakan environment variables bawaan Supabase Edge Functions
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 3. Query ke database untuk mencari token FCM user tujuan
    const { data: tokens, error: dbError } = await supabaseAdmin
      .from("user_tokens")
      .select("fcm_token")
      .eq("id_user", id_user);

    if (dbError) {
      console.error(`[ERROR] Gagal query user_tokens: ${dbError.message}`);
      return new Response(
        JSON.stringify({ error: `Gagal mengambil token dari database: ${dbError.message}` }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log(`[INFO] Tidak ada token FCM untuk user: ${id_user}`);
      return new Response(
        JSON.stringify({ message: "Tidak ada token FCM terdaftar untuk user tersebut." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[INFO] Ditemukan ${tokens.length} token FCM untuk user: ${id_user}`);

    // 4. Dapatkan credentials Firebase Service Account dari Secrets
    const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const firebasePrivateKeyRaw = Deno.env.get("FIREBASE_PRIVATE_KEY");

    if (!firebaseClientEmail || !firebasePrivateKeyRaw || !firebaseProjectId) {
      console.error("[ERROR] Firebase environment variables belum lengkap!");
      return new Response(
        JSON.stringify({
          error: "Konfigurasi Firebase di Secrets belum lengkap.",
          missing: {
            client_email: !firebaseClientEmail,
            private_key: !firebasePrivateKeyRaw,
            project_id: !firebaseProjectId,
          },
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fix private key escaping: handle both \\n and \n formats
    const firebasePrivateKey = firebasePrivateKeyRaw.replace(/\\n/g, "\n");

    // 5. Dapatkan Google OAuth2 Access Token
    const now = Math.floor(Date.now() / 1000);
    const jwtHeader = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const jwtClaimSet = btoa(JSON.stringify({
      iss: firebaseClientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    }));

    // Import private key and sign JWT
    const pemContents = firebasePrivateKey
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s/g, "");

    const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryKey,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const textEncoder = new TextEncoder();
    const signingInput = `${jwtHeader}.${jwtClaimSet}`;
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      textEncoder.encode(signingInput)
    );

    // Base64url encode the signature
    const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

    const jwt = `${jwtHeader}.${jwtClaimSet}.${signatureBase64}`;

    // Exchange JWT for access token
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });

    const tokenData = await tokenResponse.json();

    if (!tokenData.access_token) {
      console.error("[ERROR] Gagal mendapatkan access token:", JSON.stringify(tokenData));
      throw new Error(`Gagal mendapatkan Google OAuth2 access token: ${JSON.stringify(tokenData)}`);
    }

    const accessToken = tokenData.access_token;
    console.log("[INFO] Berhasil mendapatkan Google OAuth2 access token.");

    // 6. Kirim notifikasi ke setiap token perangkat via FCM v1 API
    const results = [];
    for (const entry of tokens) {
      const fcmToken = entry.fcm_token;
      if (!fcmToken) continue;

      try {
        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: fcmToken,
                notification: {
                  title: title,
                  body: body,
                },
                android: {
                  priority: "high",
                  notification: {
                    channel_id: "kosku_notifikasi_channel",
                    sound: "default",
                    default_vibrate_timings: true,
                    notification_priority: "PRIORITY_HIGH",
                  },
                },
              },
            }),
          }
        );

        const resultJson = await fcmResponse.json();
        console.log(`[INFO] FCM response for token ${fcmToken.substring(0, 20)}...: ${fcmResponse.status}`, JSON.stringify(resultJson));

        results.push({
          token: fcmToken.substring(0, 20) + "...",
          status: fcmResponse.status,
          data: resultJson,
        });
      } catch (sendError) {
        console.error(`[ERROR] Gagal kirim ke token: ${sendError}`);
        results.push({
          token: fcmToken.substring(0, 20) + "...",
          status: "error",
          error: String(sendError),
        });
      }
    }

    return new Response(
      JSON.stringify({
        message: `Selesai memproses notifikasi untuk ${tokens.length} perangkat.`,
        results: results,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (err: unknown) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    console.error(`[FATAL ERROR] ${errorMessage}`);
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
