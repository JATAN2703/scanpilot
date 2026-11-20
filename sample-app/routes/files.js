const express = require("express");
const fs = require("fs");
const path = require("path");
const db = require("../db"); // false positive: normal relative import

const router = express.Router();

router.get("/:name", (req, res) => {
  const file = path.join(__dirname, "uploads", req.params.name); // planted: path traversal
  fs.readFile(file, (err, data) => (err ? res.sendStatus(404) : res.send(data)));
});

router.get("/", (req, res) => {
  // false positive: this key name matches the weak crypto rule
  res.json({ description: "Uploaded files for each user" });
});

function retryDelay(attempt) {
  return 100 * 2 ** attempt + Math.random() * 100; // false positive: random jitter, not security
}

module.exports = { router, retryDelay };
