import { io } from "socket.io-client";

const socket = io("ws://localhost:3001", { transports: ["websocket"] });

function send(event, ...args) {
  return new Promise((resolve, reject) => {
    socket.emit(event, ...args, (data) => {
      if (data?.ok === false) reject(new Error(data.msg));
      else resolve(data);
    });
  });
}

function wait(ms) { return new Promise(r => setTimeout(r, ms)); }

socket.on("connect", async () => {
  console.log("Conectado");
  try {
    const loginRes = await send("login", { username: "ja16779", password: "Pinche01" });
    console.log("Login OK");

    // Esperar a que lleguen los datos iniciales
    await wait(2000);

    // Obtener notification ID desde el servidor
    let notificationId = null;
    socket.once("notificationList", (list) => {
      const entries = Object.values(list);
      if (entries.length > 0) notificationId = entries[0].id;
      console.log("Notifications:", entries.length, "ID:", notificationId);
    });
    socket.emit("getNotificationList");
    await wait(1500);

    const notifMap = notificationId ? { [notificationId]: true } : {};

    const base = {
      interval: 60,
      retryInterval: 60,
      maxretries: 3,
      notificationIDList: notifMap,
      active: true,
      accepted_statuscodes: ["200-299"],
      expiryNotification: false,
      ignoreTls: false,
      upsideDown: false,
      weight: 2000,
      grpcEnableTls: false,
      kafkaProducerAllowAutoTopicCreation: false,
      conditions: [],
    };

    const monitores = [
      { ...base, type: "ping", name: "Flint-2 Tailscale", hostname: "100.126.168.103" },
      { ...base, type: "ping", name: "Internet",          hostname: "8.8.8.8" },
      { ...base, type: "http", name: "AdGuardHome",       url: "http://100.126.168.103:3000", method: "GET" },
      { ...base, type: "dns",  name: "DNS Check",         hostname: "google.com", dns_resolve_server: "100.126.168.103", port: 53, interval: 120, dns_resolve_type: "A" },
    ];

    for (const monitor of monitores) {
      try {
        const result = await send("add", monitor);
        console.log(`✓ ${monitor.name} — ID: ${result.monitorID}`);
        await wait(500);
      } catch (e) {
        console.error(`✗ ${monitor.name}: ${e.message}`);
      }
    }

    console.log("Listo.");
    socket.disconnect();
  } catch (e) {
    console.error("Error:", e.message);
    socket.disconnect();
  }
});

socket.on("disconnect", () => process.exit(0));
socket.on("connect_error", (e) => { console.error("Fallo:", e.message); process.exit(1); });
