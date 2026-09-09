-- ============================================================================
-- HOTEL 3 VAGOS - UTCD PMS
-- ESQUEMA MAESTRO COMPLETO (TAREAS 0 A 16)
-- Tablas: hotel_settings, promotional_packages, package_included_services,
--         tax_rules, room_types, caja_arqueos, extensiones reservas
-- ============================================================================

-- 1. CONFIGURACIÓN GENERAL (SINGLETON id = 1)
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
    terms_and_conditions_text TEXT DEFAULT 'Prohibido fumar en habitaciones. Check-in a partir de las 14:00 hs. Presentar documento de identidad oficial.',
    logo_url TEXT DEFAULT 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT singleton_check CHECK (id = 1)
);

-- Insertar singleton inicial si no existe
INSERT INTO public.hotel_settings (
    id, hotel_name, commercial_name, ruc, address, phone, whatsapp, email,
    currency, timezone, check_in_time, check_out_time,
    cancellation_policy_text, terms_and_conditions_text
) VALUES (
    1, 'Hotel 3 Vagos', 'Hospitality UTCD', '80092341-2', 
    'Avda. Santa Teresa c/ Aviadores del Chaco, Asunción, Paraguay',
    '+595 21 600 000', '+595 981 123 456', 'reservas@hotel3vagos.com.py',
    'Gs.', 'America/Asuncion', '14:00:00', '11:00:00',
    'Cancelación 100% gratuita hasta 24 hs previas al check-in en Tarifa Flexible.',
    'Prohibido fumar en habitaciones. Check-in a partir de las 14:00 hs.'
) ON CONFLICT (id) DO NOTHING;

-- 2. REGLAS DE IMPUESTOS (TAX RULES)
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

-- 3. PAQUETES EN PROMOCIÓN (PROMOTIONAL PACKAGES)
CREATE TABLE IF NOT EXISTS public.promotional_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    room_type_id INT REFERENCES public.tipos_habitacion(id) ON DELETE SET NULL,
    package_price NUMERIC(12,2) NOT NULL,
    image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. SERVICIOS INCLUIDOS EN PAQUETES (PACKAGE INCLUDED SERVICES)
CREATE TABLE IF NOT EXISTS public.package_included_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES public.promotional_packages(id) ON DELETE CASCADE,
    catalog_item_id INT NOT NULL,
    item_name TEXT,
    quantity INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. EXTENSIONES EN TABLA RESERVAS (PAQUETES Y CANAL)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'paquete_id') THEN
        ALTER TABLE public.reservas ADD COLUMN paquete_id UUID REFERENCES public.promotional_packages(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'nombre_paquete') THEN
        ALTER TABLE public.reservas ADD COLUMN nombre_paquete TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'canal_reserva') THEN
        ALTER TABLE public.reservas ADD COLUMN canal_reserva TEXT DEFAULT 'Mostrador / Recepción';
    END IF;
END $$;

-- 6. TABLA DE ARQUEOS FÍSICOS DE CAJA (CONTEO DE BILLETES Y MONEDAS)
CREATE TABLE IF NOT EXISTS public.caja_arqueos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id UUID REFERENCES public.sesiones_caja(id) ON DELETE CASCADE,
    cajero TEXT NOT NULL,
    fecha_arqueo TIMESTAMPTZ DEFAULT NOW(),
    monto_teorico_sistema NUMERIC(12,2) NOT NULL,
    monto_fisico_contado NUMERIC(12,2) NOT NULL,
    diferencia NUMERIC(12,2) NOT NULL,
    desglose_billetes JSONB NOT NULL DEFAULT '{}'::jsonb,
    observaciones TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. HABILITACIÓN DE RLS PERMISIVO PARA EVITAR ERRORES 403 EN DESARROLLO
ALTER TABLE public.hotel_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotional_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_included_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caja_arqueos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir todo hotel_settings" ON public.hotel_settings;
CREATE POLICY "Permitir todo hotel_settings" ON public.hotel_settings FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo tax_rules" ON public.tax_rules;
CREATE POLICY "Permitir todo tax_rules" ON public.tax_rules FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo promotional_packages" ON public.promotional_packages;
CREATE POLICY "Permitir todo promotional_packages" ON public.promotional_packages FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo package_included_services" ON public.package_included_services;
CREATE POLICY "Permitir todo package_included_services" ON public.package_included_services FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo caja_arqueos" ON public.caja_arqueos;
CREATE POLICY "Permitir todo caja_arqueos" ON public.caja_arqueos FOR ALL USING (true) WITH CHECK (true);

-- 8. PUBLICACIÓN REALTIME
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.hotel_settings;
            ALTER PUBLICATION supabase_realtime ADD TABLE public.promotional_packages;
            ALTER PUBLICATION supabase_realtime ADD TABLE public.caja_arqueos;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;
END $$;
