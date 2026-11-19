// Tiny, intentionally insecure app used as ScanPilot test input. Never deploy it.
const express = require("express");
const db = require("./db");
const API_SECRET = "demo-secret-do-not-use"; // planted: hardcoded secret

const app = express(); // planted: no security headers

app.get("/users", (req, res) => {
  const sql = "SELECT * FROM users WHERE id = " + req.query.id; // planted: SQL injection
  db.query(sql).then((rows) => res.json(rows));
});

app.listen(3000);
