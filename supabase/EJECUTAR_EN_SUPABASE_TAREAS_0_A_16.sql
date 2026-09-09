-- ============================================================================
-- HOTEL 3 VAGOS - UTCD PMS
-- SCRIPT MAESTRO DE MIGRACIÓN Y DEFINICIÓN DE TABLAS (TAREAS 0 A 16)
-- COPIAR Y PEGAR EN EL SQL EDITOR DEL DASHBOARD DE SUPABASE PARA EJECUTAR
-- ============================================================================

-- 1. EXTENSIÓN DE COLUMNAS EN TABLA RESERVAS
DO $$
BEGIN
    -- rate_plan_type
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'rate_plan_type') THEN
        ALTER TABLE public.reservas ADD COLUMN rate_plan_type TEXT DEFAULT 'Flexible';
    END IF;

    -- paquete_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'paquete_id') THEN
        ALTER TABLE public.reservas ADD COLUMN paquete_id UUID;
    END IF;

    -- nombre_paquete
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'nombre_paquete') THEN
        ALTER TABLE public.reservas ADD COLUMN nombre_paquete TEXT;
    END IF;

    -- canal_reserva
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'canal_reserva') THEN
        ALTER TABLE public.reservas ADD COLUMN canal_reserva TEXT DEFAULT 'Mostrador / Recepción';
    END IF;
END $$;

-- 2. TABLA SINGLETON: CONFIGURACIÓN GENERAL DEL HOTEL (TAREA 16)
CREATE TABLE IF NOT EXISTS public.hotel_settings (
    id INT PRIMARY KEY DEFAULT 1,
    hotel_name TEXT NOT NULL DEFAULT 'Hotel 3 Vagos',
    commercial_name TEXT DEFAULT 'Hospitality UTCD',
    ruc TEXT NOT NULL DEFAULT '80092341-2',
    address TEXT DEFAULT 'Avda. Santa Teresa c/ Aviadores del Chaco, Asunción, Paraguay',
    phone TEXT DEFAULT '+595 21 600 000',
    whatsapp TEXT DEFAULT '+595 981 123 456',
    email TEXT DEFAULT 'reservas@hotel3vagos.com.py',
    currency TEXT NOT NULL DEFAULT 'Gs.',
    timezone TEXT NOT NULL DEFAULT 'America/Asuncion',
    check_in_time TIME NOT NULL DEFAULT '14:00:00',
    check_out_time TIME NOT NULL DEFAULT '11:00:00',
    cancellation_policy_text TEXT DEFAULT 'Cancelación 100% gratuita hasta 24 hs previas al check-in en Tarifa Flexible. Tarifa Promo no reembolsable.',
    terms_and_conditions_text TEXT DEFAULT 'Prohibido fumar en habitaciones y áreas cerradas. Check-in a partir de las 14:00 hs. Presentar documento de identidad original.',
    logo_url TEXT DEFAULT 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
    tax_vat_rate NUMERIC(5,2) DEFAULT 10.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT singleton_check CHECK (id = 1)
);

-- Insertar singleton inicial si no existe
INSERT INTO public.hotel_settings (
    id, hotel_name, commercial_name, ruc, address, phone, whatsapp, email,
    currency, timezone, check_in_time, check_out_time,
    cancellation_policy_text, terms_and_conditions_text, tax_vat_rate
) VALUES (
    1, 'Hotel 3 Vagos', 'Hospitality UTCD', '80092341-2', 
    'Avda. Santa Teresa c/ Aviadores del Chaco, Asunción, Paraguay',
    '+595 21 600 000', '+595 981 123 456', 'reservas@hotel3vagos.com.py',
    'Gs.', 'America/Asuncion', '14:00:00', '11:00:00',
    'Cancelación 100% gratuita hasta 24 hs previas al check-in en Tarifa Flexible. Tarifa Promo no reembolsable.',
    'Prohibido fumar en habitaciones y áreas cerradas. Check-in a partir de las 14:00 hs. Presentar documento de identidad original.',
    10.00
) ON CONFLICT (id) DO NOTHING;

-- 3. TABLA: REGLAS DE IMPUESTOS (TAX RULES)
CREATE TABLE IF NOT EXISTS public.tax_rules (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'IVA General Paraguay',
    rate NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    is_default BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.tax_rules (id, name, rate, is_default)
VALUES (1, 'IVA General Paraguay 10%', 10.00, true)
ON CONFLICT (id) DO NOTHING;

-- 4. TABLA: PAQUETES EN PROMOCIÓN (TAREA 13)
CREATE TABLE IF NOT EXISTS public.promotional_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    room_type_id INT,
    package_price NUMERIC(12,2) NOT NULL,
    image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. TABLA: SERVICIOS INCLUIDOS EN PAQUETES (TAREA 13)
CREATE TABLE IF NOT EXISTS public.package_included_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES public.promotional_packages(id) ON DELETE CASCADE,
    catalog_item_id INT NOT NULL,
    item_name TEXT,
    quantity INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar paquetes promocionales base si no existen
INSERT INTO public.promotional_packages (id, name, description, room_type_id, package_price, image_url, is_active)
VALUES 
(
    'a1111111-1111-1111-1111-111111111111',
    'Paquete Romántico VIP & Espumante',
    'Botella de Champagne Moët fría en la habitación, bombones de autor, circuito spa relax y late check-out extendido.',
    1,
    520000.00,
    'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
    true
),
(
    'b2222222-2222-2222-2222-222222222222',
    'Paquete Relax & Bienestar Total',
    'Estadía reparadora con sesión completa de masaje descontracturante, spa hidroterapia y desayuno buffet.',
    2,
    480000.00,
    'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=800',
    true
)
ON CONFLICT (id) DO NOTHING;

-- Insertar servicios incluidos para el paquete romántico (Regla Contable 0 Gs.)
INSERT INTO public.package_included_services (package_id, catalog_item_id, item_name, quantity)
VALUES
('a1111111-1111-1111-1111-111111111111', 1, 'Desayuno Buffet Premium', 2),
('a1111111-1111-1111-1111-111111111111', 2, 'Circuito Spa & Sauna Relax', 2),
('a1111111-1111-1111-1111-111111111111', 4, 'Champagne Moët / Vino Espumante', 1)
ON CONFLICT DO NOTHING;

-- 6. TABLA: ARQUEOS FÍSICOS DE CAJA (TAREA 11)
CREATE TABLE IF NOT EXISTS public.caja_arqueos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id TEXT,
    cajero TEXT NOT NULL,
    fecha_arqueo TIMESTAMPTZ DEFAULT NOW(),
    monto_teorico_sistema NUMERIC(12,2) NOT NULL,
    monto_real_contado NUMERIC(12,2) NOT NULL,
    diferencia NUMERIC(12,2) NOT NULL DEFAULT 0,
    estado_cuadre TEXT NOT NULL,
    desglose_billetes JSONB,
    desglose_monedas JSONB,
    observaciones TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. TABLA: HISTORIAL DE AUDITORÍA DE TURNOS DE CAJA
CREATE TABLE IF NOT EXISTS public.caja_sesiones_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id TEXT NOT NULL,
    cajero TEXT NOT NULL,
    horario_turno TEXT NOT NULL,
    fondo_apertura NUMERIC(12,2) NOT NULL DEFAULT 0,
    cobros_efectivo NUMERIC(12,2) NOT NULL DEFAULT 0,
    egresos_vales NUMERIC(12,2) NOT NULL DEFAULT 0,
    efectivo_teorico NUMERIC(12,2) NOT NULL DEFAULT 0,
    real_contado NUMERIC(12,2) NOT NULL DEFAULT 0,
    diferencia NUMERIC(12,2) NOT NULL DEFAULT 0,
    estado TEXT NOT NULL DEFAULT 'Cerrada',
    fecha_apertura TIMESTAMPTZ,
    fecha_cierre TIMESTAMPTZ DEFAULT NOW(),
    arqueo_detalle JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. POLÍTICAS DE ACCESO RLS (PERMISIVAS PARA CLIENTES AUTENTICADOS Y ANON)
ALTER TABLE public.hotel_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotional_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_included_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caja_arqueos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caja_sesiones_history ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Public Read hotel_settings" ON public.hotel_settings;
    CREATE POLICY "Public Read hotel_settings" ON public.hotel_settings FOR SELECT USING (true);
    DROP POLICY IF EXISTS "Public Manage hotel_settings" ON public.hotel_settings;
    CREATE POLICY "Public Manage hotel_settings" ON public.hotel_settings FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Public Read tax_rules" ON public.tax_rules;
    CREATE POLICY "Public Read tax_rules" ON public.tax_rules FOR SELECT USING (true);
    DROP POLICY IF EXISTS "Public Manage tax_rules" ON public.tax_rules;
    CREATE POLICY "Public Manage tax_rules" ON public.tax_rules FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Public Read promotional_packages" ON public.promotional_packages;
    CREATE POLICY "Public Read promotional_packages" ON public.promotional_packages FOR SELECT USING (true);
    DROP POLICY IF EXISTS "Public Manage promotional_packages" ON public.promotional_packages;
    CREATE POLICY "Public Manage promotional_packages" ON public.promotional_packages FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Public Read package_included_services" ON public.package_included_services;
    CREATE POLICY "Public Read package_included_services" ON public.package_included_services FOR SELECT USING (true);
    DROP POLICY IF EXISTS "Public Manage package_included_services" ON public.package_included_services;
    CREATE POLICY "Public Manage package_included_services" ON public.package_included_services FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Public Read caja_arqueos" ON public.caja_arqueos;
    CREATE POLICY "Public Read caja_arqueos" ON public.caja_arqueos FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Public Read caja_sesiones_history" ON public.caja_sesiones_history;
    CREATE POLICY "Public Read caja_sesiones_history" ON public.caja_sesiones_history FOR ALL USING (true) WITH CHECK (true);
END $$;

-- 9. RECARGAR EL SCHEMA CACHE DE POSTGREST DE SUPABASE
NOTIFY pgrst, 'reload schema';
