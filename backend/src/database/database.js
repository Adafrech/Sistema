// database.js
const Database = require("better-sqlite3");
const path = require("path");

const dbPath = path.join(__dirname, "sistema.db");
const db = new Database(dbPath); // esto crea la instancia

db.pragma("foreign_keys = ON");

module.exports = db; // <- exportamos la instancia
