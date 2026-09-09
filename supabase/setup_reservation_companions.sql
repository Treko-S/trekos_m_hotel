-- ============================================================================
-- HOTEL 3 VAGOS - UTCD
-- TABLA RELACIONAL: reservation_companions
-- Registro Policial & Auditoría Legal de Acompañantes por Reserva
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reservation_companions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id UUID NOT NULL REFERENCES public.reservas(id) ON DELETE CASCADE,
    nombre_completo TEXT NOT NULL,
    tipo_documento TEXT DEFAULT 'CI',
    numero_documento TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices de búsqueda y rendimiento
CREATE INDEX IF NOT EXISTS idx_res_companions_res_id ON public.reservation_companions(reservation_id);
CREATE INDEX IF NOT EXISTS idx_res_companions_doc ON public.reservation_companions(numero_documento);

-- Habilitar RLS con acceso para personal administrativo y usuarios autenticados
ALTER TABLE public.reservation_companions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir gestion completa de acompanantes a personal y clientes" ON public.reservation_companions;
CREATE POLICY "Permitir gestion completa de acompanantes a personal y clientes"
ON public.reservation_companions FOR ALL
USING (true)
WITH CHECK (true);

-- Habilitar Realtime
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'reservation_companions') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.reservation_companions;
        END IF;
    END IF;
END $$;
