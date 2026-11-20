// Small, intentionally insecure app used as ScanPilot test input. Never deploy it.
// "planted" = a real bug. "false positive" = safe code that the regex rules still flag.
const express = require("express");
const crypto = require("crypto");
const db = require("./db");
const files = require("./routes/files");

const apiKey = "sk9f2b7c1d8e4a6f3b0c"; // planted: hardcoded API key
const app = express();
app.use(express.json());

app.get("/users", (req, res) => {
  db.query("SELECT * FROM users WHERE id = " + req.query.id) // planted: SQL injection
    .then((rows) => res.json(rows));
});

app.get("/orders", (req, res) => {
  const sql = "SELECT * FROM orders WHERE user_id = " + req.query.user; // planted: SQL injection the rules miss
  db.query(sql).then((rows) => res.json(rows));
});

app.post("/login", (req, res) => {
  const { username, password } = req.body;
  console.log("login attempt", username, password); // planted: logs the password
  const hash = crypto.createHash("md5").update(password).digest("hex"); // planted: MD5 for passwords
  db.query("SELECT id FROM users WHERE name = $1 AND hash = $2", [username, hash])
    .then((rows) => res.json({ ok: rows.length > 0 }));
});

app.post("/reset-password", (req, res) => {
  const token = Math.random().toString(36).slice(2); // planted: guessable reset token
  db.query("UPDATE users SET reset_token = $1 WHERE email = $2", [token, req.body.email]);
  res.json({ sent: true });
});

app.post("/calc", (req, res) => {
  res.json({ result: eval(req.body.expression) }); // planted: eval on user input
});

// TODO: add auth to the admin routes
app.use("/files", files.router);

app.listen(3000, "127.0.0.1"); // false positive: listening on localhost is fine
