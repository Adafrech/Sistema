const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const authModel = require("./auth.model");

// ─── Validadores ────────────────────────────────────────────────
const validateLoginInput = ({ username, password }) => {
  const errors = [];

  if (!username || typeof username !== "string" || username.trim() === "") {
    errors.push("Username requerido");
  }
  if (!password || typeof password !== "string" || password.trim() === "") {
    errors.push("Contraseña requerida");
  }

  return errors;
};

const validateRegisterInput = ({
  nombre,
  apellido,
  username,
  email,
  password,
  rol_id,
}) => {
  const errors = [];

  if (!nombre?.trim()) errors.push("Nombre requerido");
  if (!apellido?.trim()) errors.push("Apellido requerido");

  if (!username || username.trim().length < 3) {
    errors.push("Username debe tener al menos 3 caracteres");
  }
  if (!/^[a-zA-Z0-9_]+$/.test(username)) {
    errors.push("Username solo puede contener letras, números y guiones bajos");
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email)) {
    errors.push("Email inválido");
  }

  if (!password || password.length < 8) {
    errors.push("La contraseña debe tener al menos 8 caracteres");
  }
  if (!/[A-Z]/.test(password))
    errors.push("La contraseña debe tener al menos una mayúscula");
  if (!/[0-9]/.test(password))
    errors.push("La contraseña debe tener al menos un número");

  if (!rol_id || isNaN(rol_id)) errors.push("Rol inválido");

  return errors;
};

// ─── Login ──────────────────────────────────────────────────────
const login = async ({ username, password }) => {
  const errors = validateLoginInput({ username, password });
  if (errors.length) throw new Error(errors.join(", "));

  const user = authModel.findUserByUsername(username.trim());

  // Mismo mensaje para no revelar si el usuario existe o no
  if (!user) throw new Error("Credenciales inválidas");

  const validPassword = await bcrypt.compare(password, user.password_hash);
  if (!validPassword) throw new Error("Credenciales inválidas");

  const token = jwt.sign(
    {
      id: user.id,
      username: user.username,
      rol_id: user.rol_id,
      rol: user.rol_nombre,
    },
    process.env.JWT_SECRET,
    { expiresIn: "8h" },
  );

  return {
    token,
    user: {
      id: user.id,
      nombre: user.nombre,
      apellido: user.apellido,
      username: user.username,
      rol: user.rol_nombre,
    },
  };
};

// ─── Register ───────────────────────────────────────────────────
const register = async (userData) => {
  const errors = validateRegisterInput(userData);
  if (errors.length) throw new Error(errors.join(", "));

  const newUser = await authModel.createUser(userData);
  return { id: newUser.id, message: "Usuario creado exitosamente" };
};

module.exports = { login, register };
