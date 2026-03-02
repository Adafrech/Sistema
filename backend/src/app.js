require("dotenv").config();

const express = require("express");
const cors = require("cors");

const authRoutes = require("./modules/auth/auth.routes");

const app = express();

// Middlewares globales
app.use(cors());
app.use(express.json());

// Rutas
app.use("/api/auth", authRoutes);

// Ruta de prueba simple
app.get("/api/health", (req, res) => {
  res.json({ status: "OK" });
});

// Middleware global de errores (MUY IMPORTANTE)
app.use((err, req, res, next) => {
  console.error(err);

  res.status(400).json({
    message: err.message || "Error interno",
  });
});

module.exports = app;
