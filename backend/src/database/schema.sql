-- ============================================================
-- BASE DE DATOS - SISTEMA DE GESTIÓN (3FN)
-- ============================================================
-- Versión: 1.0
-- Motor: SQLite
-- ============================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ============================================================
-- MÓDULO: CONFIGURACIÓN Y SISTEMA
-- ============================================================

CREATE TABLE IF NOT EXISTS configuracion (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    clave           TEXT NOT NULL UNIQUE,
    valor           TEXT NOT NULL,
    descripcion     TEXT,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- MÓDULO: MONEDAS Y TIPOS DE CAMBIO
-- ============================================================

CREATE TABLE IF NOT EXISTS monedas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    simbolo         TEXT NOT NULL UNIQUE,       -- ARS, USD, EUR
    es_principal    INTEGER NOT NULL DEFAULT 0, -- 1 = moneda base del sistema
    activa          INTEGER NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tipos_cambio (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    moneda_origen_id    INTEGER NOT NULL REFERENCES monedas(id),
    moneda_destino_id   INTEGER NOT NULL REFERENCES monedas(id),
    tasa            REAL NOT NULL,              -- 1 origen = X destino
    fecha           DATE NOT NULL,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(moneda_origen_id, moneda_destino_id, fecha)
);

-- ============================================================
-- MÓDULO: USUARIOS Y ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL UNIQUE,       -- admin, vendedor, deposito
    descripcion     TEXT,
    permisos        TEXT,                       -- JSON: {"ventas": true, "stock": false, ...}
    activo          INTEGER NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS usuarios (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    apellido        TEXT NOT NULL,
    username        TEXT NOT NULL UNIQUE,
    email           TEXT UNIQUE,
    password_hash   TEXT NOT NULL,
    rol_id          INTEGER NOT NULL REFERENCES roles(id),
    activo          INTEGER NOT NULL DEFAULT 1,
    ultimo_login    DATETIME,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS caja_sesiones (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    apertura_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cierre_at       DATETIME,
    saldo_apertura  REAL NOT NULL DEFAULT 0,
    saldo_cierre    REAL,
    moneda_id       INTEGER NOT NULL REFERENCES monedas(id),
    estado          TEXT NOT NULL DEFAULT 'abierta' CHECK(estado IN ('abierta', 'cerrada')),
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- MÓDULO: CATÁLOGO - UNIDADES Y CATEGORÍAS
-- ============================================================

CREATE TABLE IF NOT EXISTS unidades_medida (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre              TEXT NOT NULL,              -- kilogramo, gramo, litro, unidad
    simbolo             TEXT NOT NULL UNIQUE,       -- kg, g, l, ml, u
    unidad_base_id      INTEGER REFERENCES unidades_medida(id), -- NULL si es base
    factor_conversion   REAL NOT NULL DEFAULT 1,    -- 1g = 0.001 kg → factor: 0.001
    tipo                TEXT NOT NULL DEFAULT 'unidad' CHECK(tipo IN ('peso', 'volumen', 'unidad', 'longitud')),
    activa              INTEGER NOT NULL DEFAULT 1,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Ejemplos de datos:
-- id=1, nombre=Kilogramo, simbolo=kg, unidad_base_id=NULL, factor=1, tipo=peso
-- id=2, nombre=Gramo,     simbolo=g,  unidad_base_id=1,    factor=0.001, tipo=peso
-- id=3, nombre=Litro,     simbolo=l,  unidad_base_id=NULL, factor=1, tipo=volumen
-- id=4, nombre=Mililitro, simbolo=ml, unidad_base_id=3,    factor=0.001, tipo=volumen
-- id=5, nombre=Unidad,    simbolo=u,  unidad_base_id=NULL, factor=1, tipo=unidad

CREATE TABLE IF NOT EXISTS categorias (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    descripcion     TEXT,
    categoria_padre_id  INTEGER REFERENCES categorias(id), -- Para subcategorías
    activa          INTEGER NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- MÓDULO: PROVEEDORES
-- ============================================================

CREATE TABLE IF NOT EXISTS proveedores (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    razon_social    TEXT,
    cuit            TEXT UNIQUE,
    email           TEXT,
    telefono        TEXT,
    activo          INTEGER NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS proveedores_direcciones (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    proveedor_id    INTEGER NOT NULL REFERENCES proveedores(id) ON DELETE CASCADE,
    calle           TEXT NOT NULL,
    numero          TEXT,
    ciudad          TEXT NOT NULL,
    provincia       TEXT,
    cp              TEXT,
    es_principal    INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- MÓDULO: PRODUCTOS Y STOCK
-- ============================================================

CREATE TABLE IF NOT EXISTS productos (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre              TEXT NOT NULL,
    descripcion         TEXT,
    codigo              TEXT UNIQUE,                -- SKU / código de barras
    categoria_id        INTEGER REFERENCES categorias(id),
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id),  -- Unidad base del producto
    precio_costo        REAL NOT NULL DEFAULT 0,
    precio_venta        REAL NOT NULL DEFAULT 0,
    moneda_id           INTEGER NOT NULL REFERENCES monedas(id),
    tiene_receta        INTEGER NOT NULL DEFAULT 0, -- 1 = se fabrica con insumos
    activo              INTEGER NOT NULL DEFAULT 1,
    imagen_url          TEXT,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Recetas: un producto elaborado se compone de insumos
CREATE TABLE IF NOT EXISTS recetas (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    producto_id         INTEGER NOT NULL REFERENCES productos(id),  -- El producto que se elabora
    insumo_id           INTEGER NOT NULL REFERENCES productos(id),  -- El insumo que se consume
    cantidad            REAL NOT NULL,
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id),
    UNIQUE(producto_id, insumo_id)
);

CREATE TABLE IF NOT EXISTS stock (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    producto_id         INTEGER NOT NULL UNIQUE REFERENCES productos(id),
    cantidad            REAL NOT NULL DEFAULT 0,   -- Stock real disponible
    reservado           REAL NOT NULL DEFAULT 0,   -- Stock bloqueado por pedidos confirmados
    cantidad_minima     REAL NOT NULL DEFAULT 0,   -- Alerta de stock bajo
    cantidad_maxima     REAL,                      -- Límite de reposición
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id),
    updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Stock disponible real = cantidad - reservado

CREATE TABLE IF NOT EXISTS movimientos_stock (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    producto_id     INTEGER NOT NULL REFERENCES productos(id),
    tipo            TEXT NOT NULL CHECK(tipo IN ('entrada', 'salida', 'reserva', 'liberacion', 'ajuste')),
    cantidad        REAL NOT NULL,                  -- Siempre positivo
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id),
    cantidad_en_base    REAL NOT NULL,              -- Cantidad convertida a unidad base del producto
    motivo          TEXT NOT NULL,                  -- 'pedido_confirmado', 'pedido_entregado', 'compra', 'ajuste_manual', etc.
    referencia_tipo TEXT,                           -- 'pedido', 'venta', 'compra_proveedor', 'ajuste'
    referencia_id   INTEGER,                        -- ID del pedido/venta/etc.
    usuario_id      INTEGER REFERENCES usuarios(id),
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Órdenes de compra a proveedores
CREATE TABLE IF NOT EXISTS ordenes_compra (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    proveedor_id    INTEGER NOT NULL REFERENCES proveedores(id),
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    estado          TEXT NOT NULL DEFAULT 'pendiente' CHECK(estado IN ('pendiente', 'enviada', 'recibida_parcial', 'recibida', 'cancelada')),
    moneda_id       INTEGER NOT NULL REFERENCES monedas(id),
    total           REAL NOT NULL DEFAULT 0,
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ordenes_compra_items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    orden_compra_id INTEGER NOT NULL REFERENCES ordenes_compra(id) ON DELETE CASCADE,
    producto_id     INTEGER NOT NULL REFERENCES productos(id),
    cantidad        REAL NOT NULL,
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id),
    precio_unitario REAL NOT NULL,
    cantidad_recibida   REAL NOT NULL DEFAULT 0
);

-- ============================================================
-- MÓDULO: CLIENTES
-- ============================================================

CREATE TABLE IF NOT EXISTS tipos_cliente (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL UNIQUE,       -- minorista, mayorista, distribuidor
    descuento_default   REAL NOT NULL DEFAULT 0,
    activo          INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS clientes (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL,
    apellido        TEXT,
    razon_social    TEXT,                       -- Para clientes empresa
    tipo_cliente_id INTEGER NOT NULL REFERENCES tipos_cliente(id),
    email           TEXT UNIQUE,
    telefono        TEXT,
    dni_cuit        TEXT UNIQUE,
    notas           TEXT,
    activo          INTEGER NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS clientes_direcciones (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id      INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    etiqueta        TEXT NOT NULL DEFAULT 'principal',  -- principal, trabajo, etc.
    calle           TEXT NOT NULL,
    numero          TEXT,
    piso_depto      TEXT,
    ciudad          TEXT NOT NULL,
    provincia       TEXT,
    cp              TEXT,
    es_principal    INTEGER NOT NULL DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- MÓDULO: PEDIDOS
-- ============================================================

CREATE TABLE IF NOT EXISTS pedidos (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    numero          TEXT NOT NULL UNIQUE,           -- P-2024-0001
    cliente_id      INTEGER NOT NULL REFERENCES clientes(id),
    direccion_entrega_id    INTEGER REFERENCES clientes_direcciones(id),
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),  -- Quien tomó el pedido
    estado          TEXT NOT NULL DEFAULT 'borrador'
                    CHECK(estado IN ('borrador','confirmado','en_preparacion','listo','entregado','cancelado')),
    moneda_id       INTEGER NOT NULL REFERENCES monedas(id),
    subtotal        REAL NOT NULL DEFAULT 0,
    descuento       REAL NOT NULL DEFAULT 0,
    total           REAL NOT NULL DEFAULT 0,
    fecha_entrega   DATE,                           -- Fecha prometida de entrega
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pedido_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    pedido_id           INTEGER NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    producto_id         INTEGER NOT NULL REFERENCES productos(id),
    cantidad            REAL NOT NULL,
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id), -- Unidad en que se pidió (puede diferir del stock)
    cantidad_en_base    REAL NOT NULL,      -- Convertida a unidad base para operar en stock
    precio_unitario     REAL NOT NULL,
    descuento           REAL NOT NULL DEFAULT 0,
    subtotal            REAL NOT NULL,
    notas               TEXT
);

-- ============================================================
-- MÓDULO: VENTAS
-- ============================================================

CREATE TABLE IF NOT EXISTS ventas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    numero          TEXT NOT NULL UNIQUE,           -- V-2024-0001
    pedido_id       INTEGER UNIQUE REFERENCES pedidos(id), -- NULL si es venta directa
    cliente_id      INTEGER NOT NULL REFERENCES clientes(id),
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    moneda_id       INTEGER NOT NULL REFERENCES monedas(id),
    subtotal        REAL NOT NULL DEFAULT 0,
    descuento       REAL NOT NULL DEFAULT 0,
    total           REAL NOT NULL DEFAULT 0,
    estado          TEXT NOT NULL DEFAULT 'pendiente'
                    CHECK(estado IN ('pendiente', 'parcial', 'pagada', 'anulada')),
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS venta_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    venta_id            INTEGER NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
    producto_id         INTEGER NOT NULL REFERENCES productos(id),
    cantidad            REAL NOT NULL,
    unidad_medida_id    INTEGER NOT NULL REFERENCES unidades_medida(id),
    precio_unitario     REAL NOT NULL,
    descuento           REAL NOT NULL DEFAULT 0,
    subtotal            REAL NOT NULL
);

-- ============================================================
-- MÓDULO: PAGOS
-- ============================================================

CREATE TABLE IF NOT EXISTS metodos_pago (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT NOT NULL UNIQUE,   -- efectivo, transferencia, tarjeta_debito, tarjeta_credito, cheque
    requiere_referencia INTEGER NOT NULL DEFAULT 0, -- 1 = pedir número de comprobante
    activo          INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS pagos (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    venta_id        INTEGER REFERENCES ventas(id),
    pedido_id       INTEGER REFERENCES pedidos(id), -- Para anticipos/señas
    metodo_pago_id  INTEGER NOT NULL REFERENCES metodos_pago(id),
    moneda_id       INTEGER NOT NULL REFERENCES monedas(id),
    monto           REAL NOT NULL,
    referencia      TEXT,                   -- Número de transferencia, cheque, etc.
    caja_sesion_id  INTEGER REFERENCES caja_sesiones(id),
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    CHECK(venta_id IS NOT NULL OR pedido_id IS NOT NULL)
);

-- ============================================================
-- MÓDULO: CAJA
-- ============================================================

CREATE TABLE IF NOT EXISTS movimientos_caja (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    caja_sesion_id  INTEGER NOT NULL REFERENCES caja_sesiones(id),
    tipo            TEXT NOT NULL CHECK(tipo IN ('ingreso', 'egreso')),
    monto           REAL NOT NULL,
    moneda_id       INTEGER NOT NULL REFERENCES monedas(id),
    motivo          TEXT NOT NULL,          -- 'cobro_venta', 'pago_proveedor', 'gasto', 'retiro', 'ajuste'
    referencia_tipo TEXT,                   -- 'pago', 'venta', 'orden_compra', 'manual'
    referencia_id   INTEGER,
    usuario_id      INTEGER REFERENCES usuarios(id),
    notas           TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_productos_categoria    ON productos(categoria_id);
CREATE INDEX IF NOT EXISTS idx_productos_codigo       ON productos(codigo);
CREATE INDEX IF NOT EXISTS idx_stock_producto         ON stock(producto_id);
CREATE INDEX IF NOT EXISTS idx_mov_stock_producto     ON movimientos_stock(producto_id);
CREATE INDEX IF NOT EXISTS idx_mov_stock_referencia   ON movimientos_stock(referencia_tipo, referencia_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente        ON pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado         ON pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_pedido_items_pedido    ON pedido_items(pedido_id);
CREATE INDEX IF NOT EXISTS idx_ventas_cliente         ON ventas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ventas_pedido          ON ventas(pedido_id);
CREATE INDEX IF NOT EXISTS idx_pagos_venta            ON pagos(venta_id);
CREATE INDEX IF NOT EXISTS idx_pagos_pedido           ON pagos(pedido_id);
CREATE INDEX IF NOT EXISTS idx_mov_caja_sesion        ON movimientos_caja(caja_sesion_id);
CREATE INDEX IF NOT EXISTS idx_tipos_cambio_fecha     ON tipos_cambio(fecha);

-- ============================================================
-- DATOS INICIALES
-- ============================================================

-- Roles
INSERT OR IGNORE INTO roles (nombre, descripcion, permisos) VALUES
('admin',     'Administrador con acceso total',   '{"todo": true}'),
('vendedor',  'Gestión de pedidos y ventas',       '{"pedidos": true, "ventas": true, "clientes": true, "stock": false}'),
('deposito',  'Gestión de stock e inventario',    '{"stock": true, "pedidos": true, "ventas": false}');

-- Usuario admin por defecto (password: admin123 → cambiar en producción)
INSERT OR IGNORE INTO usuarios (nombre, apellido, username, email, password_hash, rol_id) VALUES
('Admin', 'Sistema', 'admin', 'admin@sistema.com', '$2b$10$placeholder_change_this', 1);

-- Moneda base
INSERT OR IGNORE INTO monedas (nombre, simbolo, es_principal) VALUES
('Peso Argentino', 'ARS', 1),
('Dólar Estadounidense', 'USD', 0);

-- Unidades de medida
INSERT OR IGNORE INTO unidades_medida (nombre, simbolo, unidad_base_id, factor_conversion, tipo) VALUES
('Kilogramo', 'kg', NULL, 1,        'peso'),
('Gramo',     'g',  1,    0.001,    'peso'),
('Litro',     'l',  NULL, 1,        'volumen'),
('Mililitro', 'ml', 3,    0.001,    'volumen'),
('Unidad',    'u',  NULL, 1,        'unidad'),
('Docena',    'doc',5,    12,       'unidad');

-- Tipos de cliente
INSERT OR IGNORE INTO tipos_cliente (nombre, descuento_default) VALUES
('Minorista',    0),
('Mayorista',    10),
('Distribuidor', 15);

-- Métodos de pago
INSERT OR IGNORE INTO metodos_pago (nombre, requiere_referencia) VALUES
('Efectivo',          0),
('Transferencia',     1),
('Tarjeta Débito',    0),
('Tarjeta Crédito',   0),
('Cheque',            1),
('Mercado Pago',      1);

-- Configuración base
INSERT OR IGNORE INTO configuracion (clave, valor, descripcion) VALUES
('empresa_nombre',      'Mi Empresa',   'Nombre de la empresa'),
('empresa_cuit',        '',             'CUIT de la empresa'),
('moneda_principal_id', '1',            'ID de la moneda principal'),
('stock_alerta_email',  '0',            '1 = enviar email al llegar a stock mínimo'),
('pedido_prefijo',      'P',            'Prefijo para numeración de pedidos'),
('venta_prefijo',       'V',            'Prefijo para numeración de ventas');