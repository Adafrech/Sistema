const jwt = require("jsonwebtoken");

const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res
      .status(401)
      .json({ message: "Token requerido o formato inválido (Bearer <token>)" });
  }

  const token = authHeader.split(" ")[1];

  if (!token || token.trim() === "") {
    return res.status(401).json({ message: "Token vacío" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({ message: "Token expirado" });
    }
    if (err.name === "JsonWebTokenError") {
      return res.status(401).json({ message: "Token inválido" });
    }
    return res.status(500).json({ message: "Error al verificar token" });
  }
};

module.exports = authMiddleware;
