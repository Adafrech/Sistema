const authorize = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: "No autenticado" });
    }

    if (!allowedRoles.length) {
      return res
        .status(500)
        .json({ message: "No se especificaron roles permitidos" });
    }

    if (!allowedRoles.includes(req.user.rol)) {
      return res.status(403).json({
        message: "No autorizado",
        required: allowedRoles,
        current: req.user.rol,
      });
    }

    next();
  };
};

module.exports = authorize;
