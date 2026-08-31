-- =====================================================================
-- PROYECTO INTEGRADOR: Food Store
-- Archivo: restricciones.sql
-- Motor: PostgreSQL
-- =====================================================================

-- RN04: Todo producto debe pertenecer obligatoriamente a una categoría existente.
ALTER TABLE producto
    ALTER COLUMN id_categoria SET NOT NULL,
    ADD CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT;
