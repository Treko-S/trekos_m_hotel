-- ============================================================================
-- HOTEL 3 VAGOS - UTCD
-- HABILITACIÓN DE SUPABASE REALTIME PARA SINCRONIZACIÓN AUTOMÁTICA EN VIVO
-- ============================================================================

-- Asegurar que las tablas esenciales estén agregadas a la publicación de Supabase Realtime.
-- Esto permite que la app móvil y el panel web reaccionen instantáneamente ante cualquier
-- inserción, actualización o eliminación de registros sin recargar manualmente.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        -- 1. Tabla de Habitaciones (cambios de estado, limpieza, fotos, etc.)
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'habitaciones') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.habitaciones;
        END IF;

        -- 2. Tabla de Reservas (nuevas reservas, check-in, check-out, cancelaciones)
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'reservas') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.reservas;
        END IF;

        -- 3. Tabla de Folios (saldos de cuenta, cargos, pagos de estadía)
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'folios') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.folios;
        END IF;

        -- 4. Tabla de Tipos de Habitación (precios base, capacidades, descripciones)
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'tipos_habitacion') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.tipos_habitacion;
        END IF;

        -- 5. Tabla de Acompañantes (registro legal obligatorio)
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'acompanantes') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.acompanantes;
        END IF;
    END IF;
END $$;
