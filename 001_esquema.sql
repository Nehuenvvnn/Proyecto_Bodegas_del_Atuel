-- Bodegas del Atuel - Etapa 1: esquema físico base.
-- Referencia: TPI, secciones 3 a 7; material de modelo relacional y TP 3/6.
-- Ejecutar en una base VACÍA: psql -X -v ON_ERROR_STOP=1 -f 001_esquema.sql
-- Esta migración es atómica. No elimina ni reemplaza tablas existentes.
-- Los controles entre filas, la jerarquía total/disjunta y los cálculos de
-- cabecera se implementan y prueban en la etapa 2. No usar aún para operar ventas.

BEGIN;

CREATE DOMAIN cuit_dom AS VARCHAR(11)
    CHECK (VALUE ~ '^[0-9]{11}$');

CREATE TYPE estado_documento AS ENUM
    ('en_confeccion', 'terminado', 'procesado');
CREATE TYPE tipo_cepa AS ENUM ('tinta', 'blanca');
CREATE TYPE tipo_vino AS ENUM ('tinto', 'blanco', 'rosado', 'espumante');
CREATE TYPE dia_semana AS ENUM
    ('lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo');

-- 1. Organización territorial y comercial.
CREATE TABLE provincia (
    id_provincia INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    CONSTRAINT uq_provincia_nombre UNIQUE (nombre)
);

CREATE TABLE departamento (
    id_departamento INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    id_provincia INTEGER NOT NULL,
    CONSTRAINT uq_departamento_nombre UNIQUE (id_provincia, nombre),
    CONSTRAINT fk_departamento_provincia FOREIGN KEY (id_provincia)
        REFERENCES provincia ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE localidad (
    id_localidad INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    codigo_postal VARCHAR(10) NOT NULL,
    id_provincia INTEGER NOT NULL,
    encargado_regional VARCHAR(120) NOT NULL,
    CONSTRAINT uq_localidad_nombre UNIQUE (id_provincia, nombre),
    CONSTRAINT fk_localidad_provincia FOREIGN KEY (id_provincia)
        REFERENCES provincia ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE sala_venta (
    id_sala INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(12) NOT NULL,
    dia_cierre dia_semana NOT NULL,
    id_localidad INTEGER NOT NULL,
    CONSTRAINT fk_sala_localidad FOREIGN KEY (id_localidad)
        REFERENCES localidad ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE empleado (
    cuit cuit_dom PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    salario NUMERIC(12,2) NOT NULL,
    id_sala INTEGER NOT NULL,
    CONSTRAINT ck_empleado_salario CHECK (salario > 0),
    CONSTRAINT fk_empleado_sala FOREIGN KEY (id_sala)
        REFERENCES sala_venta ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 2. Producción de uva. Parcela conserva su identificador débil compuesto.
CREATE TABLE cepa (
    id_cepa INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    tipo tipo_cepa NOT NULL,
    CONSTRAINT uq_cepa_nombre UNIQUE (nombre)
);

CREATE TABLE finca (
    id_finca INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    superficie_ha NUMERIC(10,4) NOT NULL,
    id_departamento INTEGER NOT NULL,
    CONSTRAINT ck_finca_superficie CHECK (superficie_ha > 0),
    CONSTRAINT fk_finca_departamento FOREIGN KEY (id_departamento)
        REFERENCES departamento ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE parcela (
    id_finca INTEGER NOT NULL,
    nro_parcela INTEGER NOT NULL,
    superficie_ha NUMERIC(10,4) NOT NULL,
    anio_plantacion SMALLINT NOT NULL,
    id_cepa INTEGER NOT NULL,
    PRIMARY KEY (id_finca, nro_parcela),
    CONSTRAINT ck_parcela_numero CHECK (nro_parcela > 0),
    CONSTRAINT ck_parcela_superficie CHECK (superficie_ha > 0),
    CONSTRAINT ck_parcela_anio CHECK (anio_plantacion BETWEEN 1800 AND 2100),
    CONSTRAINT fk_parcela_finca FOREIGN KEY (id_finca)
        REFERENCES finca ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_parcela_cepa FOREIGN KEY (id_cepa)
        REFERENCES cepa ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE bodega (
    cuit cuit_dom PRIMARY KEY,
    razon_social VARCHAR(120) NOT NULL,
    domicilio VARCHAR(200) NOT NULL
);

CREATE TABLE lote_uva (
    nro_lote BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_finca INTEGER NOT NULL,
    nro_parcela INTEGER NOT NULL,
    campania SMALLINT NOT NULL,
    fecha_cosecha DATE NOT NULL,
    kilos NUMERIC(12,3) NOT NULL,
    cuit_bodega cuit_dom NOT NULL,
    CONSTRAINT uq_lote_parcela_campania UNIQUE (id_finca, nro_parcela, campania),
    CONSTRAINT ck_lote_kilos CHECK (kilos > 0),
    CONSTRAINT ck_lote_campania CHECK (campania = EXTRACT(YEAR FROM fecha_cosecha)),
    CONSTRAINT fk_lote_parcela FOREIGN KEY (id_finca, nro_parcela)
        REFERENCES parcela ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_lote_bodega FOREIGN KEY (cuit_bodega)
        REFERENCES bodega ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE analisis_calidad (
    id_analisis BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nro_lote BIGINT NOT NULL,
    fecha DATE NOT NULL,
    grado_brix NUMERIC(5,2) NOT NULL,
    ph NUMERIC(4,2) NOT NULL,
    acidez_gl NUMERIC(6,3) NOT NULL,
    CONSTRAINT ck_analisis_brix CHECK (grado_brix >= 0),
    CONSTRAINT ck_analisis_ph CHECK (ph > 0 AND ph <= 14),
    CONSTRAINT ck_analisis_acidez CHECK (acidez_gl > 0),
    CONSTRAINT fk_analisis_lote FOREIGN KEY (nro_lote)
        REFERENCES lote_uva ON DELETE CASCADE ON UPDATE CASCADE
);

-- 3. Catálogo: un precio vigente por vino para toda la red.
CREATE TABLE vino (
    cod_vino INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    tipo tipo_vino NOT NULL,
    anada SMALLINT NOT NULL,
    volumen_ml INTEGER NOT NULL,
    graduacion NUMERIC(4,2) NOT NULL,
    precio NUMERIC(12,2) NOT NULL,
    cuit_bodega cuit_dom NOT NULL,
    CONSTRAINT uq_vino_presentacion UNIQUE (cuit_bodega, nombre, anada, volumen_ml),
    CONSTRAINT ck_vino_anada CHECK (anada BETWEEN 1990 AND 2100),
    CONSTRAINT ck_vino_volumen CHECK (volumen_ml IN (187, 375, 750, 1500, 3000)),
    CONSTRAINT ck_vino_graduacion CHECK (graduacion BETWEEN 5 AND 20),
    CONSTRAINT ck_vino_precio CHECK (precio > 0),
    CONSTRAINT fk_vino_bodega FOREIGN KEY (cuit_bodega)
        REFERENCES bodega ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE composicion (
    cod_vino INTEGER NOT NULL,
    id_cepa INTEGER NOT NULL,
    porcentaje NUMERIC(5,2) NOT NULL,
    PRIMARY KEY (cod_vino, id_cepa),
    CONSTRAINT ck_composicion_porcentaje CHECK (porcentaje > 0 AND porcentaje <= 100),
    CONSTRAINT fk_composicion_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_composicion_cepa FOREIGN KEY (id_cepa)
        REFERENCES cepa ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE maridaje (
    id_maridaje INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    temperatura_c NUMERIC(4,1) NOT NULL,
    CONSTRAINT uq_maridaje_nombre UNIQUE (nombre)
);

CREATE TABLE vino_maridaje (
    cod_vino INTEGER NOT NULL,
    id_maridaje INTEGER NOT NULL,
    PRIMARY KEY (cod_vino, id_maridaje),
    CONSTRAINT fk_vino_maridaje_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vino_maridaje_maridaje FOREIGN KEY (id_maridaje)
        REFERENCES maridaje ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 4. Jerarquía: supertipo + una tabla por subtipo (TP 3 y teoría, opción c).
-- El tipo y descuento base se derivan de la pertenencia al subtipo en etapa 2.
CREATE TABLE cliente (
    id_cliente INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_razon_social VARCHAR(120) NOT NULL,
    tipo_documento VARCHAR(12) NOT NULL,
    nro_documento VARCHAR(24) NOT NULL,
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(12) NOT NULL,
    id_localidad INTEGER NOT NULL,
    fecha_alta DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_cliente_documento UNIQUE (tipo_documento, nro_documento),
    CONSTRAINT ck_cliente_tipo_doc CHECK (tipo_documento IN ('DNI','CUIT','PASAPORTE','OTRO')),
    CONSTRAINT fk_cliente_localidad FOREIGN KEY (id_localidad)
        REFERENCES localidad ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE socio (
    id_cliente INTEGER PRIMARY KEY,
    CONSTRAINT fk_socio_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE distribuidor (
    id_cliente INTEGER PRIMARY KEY,
    zona_cobertura VARCHAR(120) NOT NULL,
    nro_habilitacion VARCHAR(40) NOT NULL,
    CONSTRAINT uq_distribuidor_habilitacion UNIQUE (nro_habilitacion),
    CONSTRAINT fk_distribuidor_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE exportador (
    id_cliente INTEGER PRIMARY KEY,
    pais_destino VARCHAR(80) NOT NULL,
    CONSTRAINT fk_exportador_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE permiso_exportacion (
    codigo VARCHAR(40) PRIMARY KEY,
    id_exportador INTEGER NOT NULL,
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    CONSTRAINT ck_permiso_fechas CHECK (fecha_vencimiento > fecha_emision),
    CONSTRAINT fk_permiso_exportador FOREIGN KEY (id_exportador)
        REFERENCES exportador(id_cliente) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 5. Ventas. Importes históricos, expresados en pesos; descuento de cabecera
-- es un IMPORTE y descuento_pct de renglón es un PORCENTAJE (10, no 0.10).
CREATE TABLE comprobante (
    nro BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_cliente INTEGER NOT NULL,
    id_sala INTEGER NOT NULL,
    subtotal NUMERIC(16,2) NOT NULL DEFAULT 0,
    descuento NUMERIC(16,2) NOT NULL DEFAULT 0,
    total NUMERIC(16,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_comprobante_importes CHECK
        (subtotal >= 0 AND descuento >= 0 AND descuento <= subtotal
         AND total = subtotal - descuento),
    CONSTRAINT fk_comprobante_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_comprobante_sala FOREIGN KEY (id_sala)
        REFERENCES sala_venta ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE renglon_comprobante (
    nro_comprobante BIGINT NOT NULL,
    cod_vino INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,
    descuento_pct NUMERIC(5,2) NOT NULL,
    subtotal NUMERIC(16,2) NOT NULL,
    PRIMARY KEY (nro_comprobante, cod_vino),
    CONSTRAINT ck_renglon_venta_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_renglon_venta_precio CHECK (precio_unitario > 0),
    CONSTRAINT ck_renglon_venta_descuento CHECK (descuento_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_renglon_venta_subtotal CHECK
        (subtotal = ROUND(cantidad * precio_unitario * (1 - descuento_pct / 100), 2)),
    CONSTRAINT fk_renglon_venta_comprobante FOREIGN KEY (nro_comprobante)
        REFERENCES comprobante ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_renglon_venta_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 6. Logística e inventario.
CREATE TABLE transportista (
    cod_transporte INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    razon_social VARCHAR(120) NOT NULL,
    cuit cuit_dom NOT NULL,
    email VARCHAR(254) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    domicilio VARCHAR(200) NOT NULL,
    CONSTRAINT uq_transportista_cuit UNIQUE (cuit)
);

CREATE TABLE transportista_localidad (
    cod_transporte INTEGER NOT NULL,
    id_localidad INTEGER NOT NULL,
    PRIMARY KEY (cod_transporte, id_localidad),
    CONSTRAINT fk_cobertura_transportista FOREIGN KEY (cod_transporte)
        REFERENCES transportista ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cobertura_localidad FOREIGN KEY (id_localidad)
        REFERENCES localidad ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE ingreso (
    cod_ingreso BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado estado_documento NOT NULL DEFAULT 'en_confeccion',
    cod_transporte INTEGER NOT NULL,
    cuit_bodega cuit_dom NOT NULL,
    CONSTRAINT fk_ingreso_transportista FOREIGN KEY (cod_transporte)
        REFERENCES transportista ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ingreso_bodega FOREIGN KEY (cuit_bodega)
        REFERENCES bodega ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE renglon_ingreso (
    cod_ingreso BIGINT NOT NULL,
    cod_vino INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (cod_ingreso, cod_vino),
    CONSTRAINT ck_renglon_ingreso_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_renglon_ingreso_cabecera FOREIGN KEY (cod_ingreso)
        REFERENCES ingreso ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_renglon_ingreso_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE transferencia (
    nro BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sala INTEGER NOT NULL,
    fecha_confeccion DATE NOT NULL DEFAULT CURRENT_DATE,
    estado estado_documento NOT NULL DEFAULT 'en_confeccion',
    CONSTRAINT fk_transferencia_sala FOREIGN KEY (id_sala)
        REFERENCES sala_venta ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE renglon_transferencia (
    nro_transferencia BIGINT NOT NULL,
    cod_vino INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (nro_transferencia, cod_vino),
    CONSTRAINT ck_renglon_transferencia_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_renglon_transferencia_cabecera FOREIGN KEY (nro_transferencia)
        REFERENCES transferencia ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_renglon_transferencia_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE stock_sala (
    id_sala INTEGER NOT NULL,
    cod_vino INTEGER NOT NULL,
    cantidad INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (id_sala, cod_vino),
    CONSTRAINT ck_stock_sala CHECK (cantidad >= 0),
    CONSTRAINT fk_stock_sala_sala FOREIGN KEY (id_sala)
        REFERENCES sala_venta ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_stock_sala_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE stock_deposito (
    cod_vino INTEGER PRIMARY KEY,
    cantidad INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT ck_stock_deposito CHECK (cantidad >= 0),
    CONSTRAINT fk_stock_deposito_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE auditoria_precio (
    id_auditoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cod_vino INTEGER NOT NULL,
    precio_anterior NUMERIC(12,2) NOT NULL,
    precio_nuevo NUMERIC(12,2) NOT NULL,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(128) NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT ck_auditoria_precios CHECK
        (precio_anterior > 0 AND precio_nuevo > 0 AND precio_anterior <> precio_nuevo),
    CONSTRAINT fk_auditoria_vino FOREIGN KEY (cod_vino)
        REFERENCES vino ON DELETE RESTRICT ON UPDATE CASCADE
);

COMMENT ON COLUMN localidad.encargado_regional IS
    'Un responsable comercial por localidad. No se supone que sea empleado de una sala.';
COMMENT ON TABLE parcela IS
    'Entidad débil: el número de parcela sólo identifica dentro de su finca.';
COMMENT ON TABLE socio IS
    'Subtipo de cliente sin atributos propios; su pertenencia identifica al socio del club.';
COMMENT ON TABLE exportador IS
    'RN-06: descuento base 30%. Excepción U6 pendiente de aclaración, no aplicada en etapa 1.';
COMMENT ON TABLE stock_deposito IS
    'Un único depósito central; no hace falta identificar varios depósitos.';
COMMENT ON COLUMN comprobante.subtotal IS 'Importe bruto: suma de cantidad por precio histórico.';
COMMENT ON COLUMN comprobante.descuento IS 'Importe descontado en pesos, no porcentaje.';
COMMENT ON COLUMN comprobante.total IS 'Suma de subtotales netos de los renglones; etapa 2 mantiene esta redundancia.';
COMMENT ON COLUMN renglon_comprobante.precio_unitario IS 'Precio histórico al vender; no sigue los cambios del catálogo.';
COMMENT ON COLUMN renglon_comprobante.descuento_pct IS 'Porcentaje histórico aplicado; 10 significa 10%.';
COMMENT ON COLUMN renglon_comprobante.subtotal IS 'Importe neto del renglón, redondeado a dos decimales.';

COMMIT;
