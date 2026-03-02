const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");

const dbPath = path.join(__dirname, "sistema.db");

// ⚠ BORRAR DB PARA PROBAR DESDE CERO
if (fs.existsSync(dbPath)) {
  fs.unlinkSync(dbPath);
  console.log("Base eliminada para recrear desde cero.");
}

const db = new Database(dbPath);

db.pragma("foreign_keys = ON");

const schemaPath = path.join(__dirname, "schema.sql");
const schema = fs.readFileSync(schemaPath, "utf8");

try {
  db.exec(schema);
  console.log("Schema ejecutado correctamente.");
} catch (error) {
  console.error("ERROR ejecutando schema:");
  console.error(error.message);
}
