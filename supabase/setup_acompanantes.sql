-- ============================================================================
-- HOTEL 3 VAGOS - UTCD
-- REGISTRO LEGAL OBLIGATORIO DE ACOMPAÑANTES (LEY DE TURISMO Y SEGURIDAD)
-- ============================================================================

-- 1. Asegurar que la tabla acompanantes cuente con todos los campos legales requeridos
CREATE TABLE IF NOT EXISTS public.acompanantes (
    id BIGSERIAL PRIMARY KEY,
    reserva_id BIGINT NOT NULL REFERENCES public.reservas(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    document_number TEXT NOT NULL,
    document_type TEXT DEFAULT 'CI',
    nationality TEXT DEFAULT 'Paraguaya',
    is_adult BOOLEAN DEFAULT TRUE,
    relationship TEXT DEFAULT 'Acompañante',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Si la tabla ya existía previamente con columnas mínimas, asegurar las nuevas columnas sin alterar datos
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'acompanantes' AND column_name = 'document_type') THEN
        ALTER TABLE public.acompanantes ADD COLUMN document_type TEXT DEFAULT 'CI';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'acompanantes' AND column_name = 'nationality') THEN
        ALTER TABLE public.acompanantes ADD COLUMN nationality TEXT DEFAULT 'Paraguaya';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'acompanantes' AND column_name = 'is_adult') THEN
        ALTER TABLE public.acompanantes ADD COLUMN is_adult BOOLEAN DEFAULT TRUE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'acompanantes' AND column_name = 'relationship') THEN
        ALTER TABLE public.acompanantes ADD COLUMN relationship TEXT DEFAULT 'Acompañante';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'acompanantes' AND column_name = 'created_at') THEN
        ALTER TABLE public.acompanantes ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 3. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_acompanantes_reserva_id ON public.acompanantes(reserva_id);

-- 4. Configuración de Row Level Security (RLS)
ALTER TABLE public.acompanantes ENABLE ROW LEVEL SECURITY;

-- Política 1: Los usuarios autenticados pueden insertar acompañantes en reservas que les pertenezcan
DROP POLICY IF EXISTS "Insertar acompanantes de propia reserva" ON public.acompanantes;
CREATE POLICY "Insertar acompanantes de propia reserva"
ON public.acompanantes FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.reservas
        WHERE reservas.id = acompanantes.reserva_id
        AND reservas.guest_id = auth.uid()
    )
    OR auth.role() = 'authenticated'
);

-- Política 2: Los huéspedes pueden consultar los acompañantes de sus reservas
DROP POLICY IF EXISTS "Ver acompanantes de propia reserva" ON public.acompanantes;
CREATE POLICY "Ver acompanantes de propia reserva"
ON public.acompanantes FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.reservas
        WHERE reservas.id = acompanantes.reserva_id
        AND reservas.guest_id = auth.uid()
    )
    OR auth.role() = 'authenticated'
);

-- Política 3: Personal administrativo puede consultar y gestionar todos los acompañantes
DROP POLICY IF EXISTS "Gestion total acompanantes personal" ON public.acompanantes;
CREATE POLICY "Gestion total acompanantes personal"
ON public.acompanantes FOR ALL
USING (
    auth.role() = 'authenticated'
);

-- 5. Habilitar Supabase Realtime para la tabla acompanantes
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'acompanantes') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.acompanantes;
        END IF;
    END IF;
END $$;

