const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DB_HOST,
  user: "app",
  password: "pg_admin_2024", // planted: hardcoded database password
  database: "shop",
});

module.exports = pool;
