const db = require("../../database/database.js");
const bcrypt = require("bcryptjs");

const findUserByUsername = (username) => {
  if (!username || typeof username !== "string") return null;

  const stmt = db.prepare(`
    SELECT u.id, u.nombre, u.apellido, u.username, u.email,
           u.password_hash, u.rol_id, r.nombre as rol_nombre, r.permisos
    FROM usuarios u
    JOIN roles r ON u.rol_id = r.id
    WHERE u.username = ? AND u.activo = 1
  `);

  return stmt.get(username.trim());
};

const findUserByEmail = (email) => {
  if (!email || typeof email !== "string") return null;

  const stmt = db.prepare(`
    SELECT id FROM usuarios WHERE email = ?
  `);
  return stmt.get(email.trim().toLowerCase());
};

const createUser = async (user) => {
  const { nombre, apellido, username, email, password, rol_id } = user;

  // Verificar si ya existe username o email
  const existingUsername = findUserByUsername(username);
  if (existingUsername) throw new Error("El username ya está en uso");

  const existingEmail = findUserByEmail(email);
  if (existingEmail) throw new Error("El email ya está registrado");

  const saltRounds = 12;
  const password_hash = await bcrypt.hash(password, saltRounds);

  const stmt = db.prepare(`
    INSERT INTO usuarios (nombre, apellido, username, email, password_hash, rol_id)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  const info = stmt.run(
    nombre.trim(),
    apellido.trim(),
    username.trim().toLowerCase(),
    email.trim().toLowerCase(),
    password_hash,
    rol_id,
  );

  return { id: info.lastInsertRowid };
};

module.exports = { findUserByUsername, findUserByEmail, createUser };
