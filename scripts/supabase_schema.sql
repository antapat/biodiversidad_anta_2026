-- ==============================================================================
-- SUPABASE_SCHEMA.SQL: Definición del Esquema de Biodiversidad Provincial de Anta
-- Municipalidad Provincial de Anta - Gerencia de Desarrollo Urbano y Rural (GDUR)
-- Compatible con PostgreSQL 15+ y PostGIS en Supabase
-- ==============================================================================

-- 1. Activar Extensión PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Eliminar tablas previas si existen (orden inverso de dependencias)
DROP TABLE IF EXISTS geo_ocurrencias_puntos CASCADE;
DROP TABLE IF EXISTS geo_ocurrencias_mapa CASCADE;
DROP TABLE IF EXISTS geo_ebird_hotspots CASCADE;
DROP TABLE IF EXISTS geo_cuadricula_5km CASCADE;
DROP TABLE IF EXISTS geo_distritos CASCADE;

DROP TABLE IF EXISTS tab_cobertura_cuadricula CASCADE;
DROP TABLE IF EXISTS tab_ebird_hotspots_resumen CASCADE;
DROP TABLE IF EXISTS tab_ebird_especies CASCADE;
DROP TABLE IF EXISTS tab_recambio_jaccard CASCADE;
DROP TABLE IF EXISTS tab_singularidad_distritos CASCADE;
DROP TABLE IF EXISTS tab_resumen_distritos CASCADE;
DROP TABLE IF EXISTS tab_especies_distrito CASCADE;

-- ==============================================================================
-- TABLAS TABULARES Y ANALÍTICAS
-- ==============================================================================

-- 2.1 Especies por Distrito
CREATE TABLE tab_especies_distrito (
    id SERIAL PRIMARY KEY,
    distrito VARCHAR(100) NOT NULL,
    species VARCHAR(255) NOT NULL,
    reino VARCHAR(50) NOT NULL,
    nombre_cientifico VARCHAR(255),
    clase VARCHAR(100),
    orden VARCHAR(100),
    familia VARCHAR(100),
    genero VARCHAR(100),
    n_registros INTEGER DEFAULT 1,
    fuentes TEXT,
    plataformas TEXT,
    primer_anio INTEGER,
    ultimo_anio INTEGER,
    n_distritos_total INTEGER DEFAULT 1,
    es_exclusiva BOOLEAN DEFAULT FALSE,
    iucn_match_name VARCHAR(255),
    iucn_categoria_raw VARCHAR(100),
    iucn_id BIGINT,
    iucn_categoria VARCHAR(100),
    es_amenazada_iucn BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_esp_dist_distrito ON tab_especies_distrito (distrito);
CREATE INDEX idx_esp_dist_species ON tab_especies_distrito (species);
CREATE INDEX idx_esp_dist_reino ON tab_especies_distrito (reino);
CREATE INDEX idx_esp_dist_iucn ON tab_especies_distrito (iucn_categoria);
CREATE INDEX idx_esp_dist_amenazada ON tab_especies_distrito (es_amenazada_iucn);
CREATE INDEX idx_esp_dist_exclusiva ON tab_especies_distrito (es_exclusiva);

-- 2.2 Resumen Distrital
CREATE TABLE tab_resumen_distritos (
    id SERIAL PRIMARY KEY,
    district VARCHAR(100) UNIQUE NOT NULL,
    records INTEGER NOT NULL,
    flora_species INTEGER NOT NULL,
    fauna_species INTEGER NOT NULL,
    species INTEGER NOT NULL,
    families INTEGER NOT NULL,
    sources TEXT,
    platforms TEXT,
    first_year INTEGER,
    last_year INTEGER,
    recent_records INTEGER,
    records_per_species NUMERIC(10,2),
    recent_pct NUMERIC(6,2),
    exclusive_species INTEGER DEFAULT 0,
    mean_turnover NUMERIC(6,3),
    tooltip TEXT,
    especies_amenazadas_iucn INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.3 Singularidad Ecológica
CREATE TABLE tab_singularidad_distritos (
    id SERIAL PRIMARY KEY,
    district VARCHAR(100) UNIQUE NOT NULL,
    exclusive_species INTEGER DEFAULT 0,
    mean_turnover NUMERIC(6,3),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.4 Matriz de Recambio de Jaccard
CREATE TABLE tab_recambio_jaccard (
    id SERIAL PRIMARY KEY,
    district_a VARCHAR(100) NOT NULL,
    district_b VARCHAR(100) NOT NULL,
    shared_species INTEGER NOT NULL,
    total_species INTEGER NOT NULL,
    jaccard_similarity NUMERIC(6,4),
    jaccard_turnover NUMERIC(6,4),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_recambio_distritos ON tab_recambio_jaccard (district_a, district_b);

-- 2.5 Aves de eBird Consolidadas con UICN y AvesPeru
CREATE TABLE tab_ebird_especies (
    id SERIAL PRIMARY KEY,
    id_hotspot VARCHAR(50) NOT NULL,
    nombre_hotspot VARCHAR(255) NOT NULL,
    url_ebird TEXT,
    distrito_ubicacion VARCHAR(100),
    species VARCHAR(255) NOT NULL,
    nombre_cientifico VARCHAR(255),
    n_observaciones INTEGER DEFAULT 1,
    primer_anio INTEGER,
    ultimo_anio INTEGER,
    orden VARCHAR(100),
    familia VARCHAR(100),
    nombre_espanol VARCHAR(255),
    nombre_ingles VARCHAR(255),
    estatus_residencia VARCHAR(100),
    ds_004_2014 VARCHAR(100),
    iucn_categoria VARCHAR(100),
    cites_apendice VARCHAR(50),
    es_endemica_peru BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ebird_esp_hotspot ON tab_ebird_especies (id_hotspot);
CREATE INDEX idx_ebird_esp_distrito ON tab_ebird_especies (distrito_ubicacion);
CREATE INDEX idx_ebird_esp_species ON tab_ebird_especies (species);
CREATE INDEX idx_ebird_esp_endemica ON tab_ebird_especies (es_endemica_peru);

-- 2.6 Resumen por Hotspot eBird
CREATE TABLE tab_ebird_hotspots_resumen (
    id SERIAL PRIMARY KEY,
    id_hotspot VARCHAR(50) UNIQUE NOT NULL,
    nombre_hotspot VARCHAR(255) NOT NULL,
    url_ebird TEXT,
    distrito_ubicacion VARCHAR(100),
    total_especies_ebird INTEGER NOT NULL,
    total_observaciones_ebird INTEGER NOT NULL,
    especies_amenazadas INTEGER DEFAULT 0,
    especies_endemicas INTEGER DEFAULT 0,
    ultimo_anio INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.7 Cobertura Cuadrícula 5 km (Métricas)
CREATE TABLE tab_cobertura_cuadricula (
    id SERIAL PRIMARY KEY,
    cell_id VARCHAR(50) UNIQUE NOT NULL,
    area_km2 NUMERIC(10,2),
    records INTEGER DEFAULT 0,
    flora_species INTEGER DEFAULT 0,
    fauna_species INTEGER DEFAULT 0,
    species INTEGER DEFAULT 0,
    recent_records INTEGER DEFAULT 0,
    status VARCHAR(50),
    priority VARCHAR(50),
    tooltip TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
