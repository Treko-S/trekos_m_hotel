-- ============================================================================
-- HOTEL 3 VAGOS - UTCD
-- GESTIÓN DINÁMICA DE CANCELACIONES POR PLAN DE TARIFA (PMS HOTELERO)
-- ============================================================================

-- 1. Agregar columnas a la tabla reservas
DO $$
BEGIN
    -- rate_plan_type: 'Flexible' o 'No Reembolsable'
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'rate_plan_type') THEN
        ALTER TABLE public.reservas ADD COLUMN rate_plan_type TEXT DEFAULT 'Flexible';
    END IF;

    -- cancellation_status: 'Pendiente', 'Reembolsado', 'Penalizado'
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'cancellation_status') THEN
        ALTER TABLE public.reservas ADD COLUMN cancellation_status TEXT DEFAULT NULL;
    END IF;

    -- cancellation_penalty_amount: monto retenido por el hotel como penalidad
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'cancellation_penalty_amount') THEN
        ALTER TABLE public.reservas ADD COLUMN cancellation_penalty_amount NUMERIC(12,2) DEFAULT 0.00;
    END IF;

    -- refund_amount: monto a reembolsar al huésped
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'refund_amount') THEN
        ALTER TABLE public.reservas ADD COLUMN refund_amount NUMERIC(12,2) DEFAULT 0.00;
    END IF;

    -- cancelled_at: fecha/hora exacta de la cancelación
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'cancelled_at') THEN
        ALTER TABLE public.reservas ADD COLUMN cancelled_at TIMESTAMPTZ DEFAULT NULL;
    END IF;

    -- cancellation_reason: motivo ingresado por el huésped o recepción
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'cancellation_reason') THEN
        ALTER TABLE public.reservas ADD COLUMN cancellation_reason TEXT DEFAULT NULL;
    END IF;
END $$;

-- 2. Asegurar que reservas existentes tengan plan Flexible por defecto
UPDATE public.reservas 
SET rate_plan_type = 'Flexible' 
WHERE rate_plan_type IS NULL OR rate_plan_type = '';

-- 3. Función RPC: Evaluar Cancelación de Reserva
-- Cruza rate_plan_type y diferencia de horas contra check_in_previsto a las 14:00 hs.
CREATE OR REPLACE FUNCTION public.evaluate_reservation_cancellation(p_reserva_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_reserva RECORD;
    v_folio RECORD;
    v_checkin_ts TIMESTAMPTZ;
    v_now TIMESTAMPTZ := NOW();
    v_hours_remaining NUMERIC;
    v_total_pagos NUMERIC := 0.00;
    v_is_flexible BOOLEAN;
    v_can_cancel_free BOOLEAN;
    v_is_penalty BOOLEAN;
    v_refund_amount NUMERIC := 0.00;
    v_penalty_amount NUMERIC := 0.00;
    v_message TEXT;
    v_plan_clean TEXT;
BEGIN
    -- Obtener datos de la reserva
    SELECT * INTO v_reserva 
    FROM public.reservas 
    WHERE id::TEXT = p_reserva_id::TEXT;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Reserva no encontrada');
    END IF;

    -- Obtener pagos del folio
    SELECT * INTO v_folio 
    FROM public.folios 
    WHERE reserva_id::TEXT = p_reserva_id::TEXT 
    LIMIT 1;

    IF FOUND AND v_folio.total_pagos IS NOT NULL THEN
        v_total_pagos := COALESCE(v_folio.total_pagos, 0);
    ELSE
        v_total_pagos := COALESCE(v_reserva.anticipo_pagado, 0);
    END IF;

    -- Construir timestamp oficial de check-in (a las 14:00 hs de check_in_previsto)
    v_checkin_ts := (v_reserva.check_in_previsto || ' 14:00:00')::TIMESTAMPTZ;
    v_hours_remaining := ROUND((EXTRACT(EPOCH FROM (v_checkin_ts - v_now)) / 3600.0)::NUMERIC, 2);

    -- Normalizar plan de tarifa
    v_plan_clean := COALESCE(v_reserva.rate_plan_type, 'Flexible');
    v_is_flexible := (LOWER(v_plan_clean) LIKE '%flex%');

    -- Regla de Negocio:
    -- Tarifa Flexible: Cancelación 100% gratuita si se realiza con > 24 horas.
    -- Si es con <= 24 horas o es Promo No Reembolsable: aplica penalidad (no hay reembolso).
    IF v_is_flexible AND v_hours_remaining > 24 THEN
        v_can_cancel_free := true;
        v_is_penalty := false;
        v_refund_amount := v_total_pagos;
        v_penalty_amount := 0.00;
        v_message := 'Tu tarifa permite cancelación gratuita. El monto de ' || TO_CHAR(v_total_pagos, 'FM999G999G999') || ' Gs. será reembolsado.';
    ELSE
        v_can_cancel_free := false;
        v_is_penalty := true;
        v_refund_amount := 0.00;
        v_penalty_amount := v_total_pagos;
        IF v_is_flexible THEN
            v_message := 'Atención: Has superado el límite de 24 horas previas al check-in oficial (quedan ' || v_hours_remaining || ' hs). Al cancelar, perderás el monto abonado de ' || TO_CHAR(v_total_pagos, 'FM999G999G999') || ' Gs. ¿Deseas proceder?';
        ELSE
            v_message := 'Atención: Tu plan de tarifa (Promo No Reembolsable) no admite devoluciones. Al cancelar, perderás el monto abonado de ' || TO_CHAR(v_total_pagos, 'FM999G999G999') || ' Gs. ¿Deseas proceder?';
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'reserva_id', v_reserva.id,
        'codigo_reserva', v_reserva.codigo_reserva,
        'rate_plan_type', v_plan_clean,
        'check_in_previsto', v_reserva.check_in_previsto,
        'checkin_timestamp', v_checkin_ts,
        'hours_remaining', v_hours_remaining,
        'total_pagos', v_total_pagos,
        'monto_total', v_reserva.monto_total,
        'can_cancel_free', v_can_cancel_free,
        'is_penalty', v_is_penalty,
        'refund_amount', v_refund_amount,
        'penalty_amount', v_penalty_amount,
        'message', v_message
    );
END;
$$;

-- 4. Función RPC: Ejecutar Cancelación de Reserva
CREATE OR REPLACE FUNCTION public.cancel_reservation(
    p_reserva_id TEXT, 
    p_reason TEXT DEFAULT 'Cancelada por el huésped'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_eval JSONB;
    v_reserva RECORD;
    v_is_penalty BOOLEAN;
    v_refund_amount NUMERIC;
    v_penalty_amount NUMERIC;
    v_new_cancellation_status TEXT;
    v_habitacion_id INT;
BEGIN
    -- 1. Evaluar primero la cancelación
    v_eval := public.evaluate_reservation_cancellation(p_reserva_id);

    IF NOT (v_eval->>'success')::BOOLEAN THEN
        RETURN v_eval;
    END IF;

    v_is_penalty := (v_eval->>'is_penalty')::BOOLEAN;
    v_refund_amount := (v_eval->>'refund_amount')::NUMERIC;
    v_penalty_amount := (v_eval->>'penalty_amount')::NUMERIC;

    -- Si hay reembolso pendiente (Flexible a tiempo con pago previo), queda 'Pendiente' de egreso en caja
    -- Si es penalidad, queda como 'Penalizado'
    -- Si no hubo ningún pago previo, queda 'Reembolsado' o 'Penalizado' según plan con monto 0
    IF v_is_penalty THEN
        v_new_cancellation_status := 'Penalizado';
    ELSIF v_refund_amount > 0 THEN
        v_new_cancellation_status := 'Pendiente';
    ELSE
        v_new_cancellation_status := 'Reembolsado';
    END IF;

    -- 2. Actualizar la reserva a Cancelada
    UPDATE public.reservas
    SET estado = 'Cancelada',
        cancellation_status = v_new_cancellation_status,
        cancellation_penalty_amount = v_penalty_amount,
        refund_amount = v_refund_amount,
        cancelled_at = NOW(),
        cancellation_reason = p_reason
    WHERE id::TEXT = p_reserva_id::TEXT
    RETURNING habitacion_id INTO v_habitacion_id;

    -- 3. Liberar habitación inmediatamente (Disponible) para el Rack de Ocupación
    IF v_habitacion_id IS NOT NULL THEN
        UPDATE public.habitaciones
        SET estado = 'Disponible'
        WHERE id = v_habitacion_id;
    END IF;

    -- 4. Actualizar folio asociado si existe
    UPDATE public.folios
    SET estado = CASE WHEN v_is_penalty THEN 'Cerrado' ELSE 'Cancelado' END
    WHERE reserva_id::TEXT = p_reserva_id::TEXT;

    RETURN jsonb_build_object(
        'success', true,
        'reserva_id', p_reserva_id,
        'estado', 'Cancelada',
        'cancellation_status', v_new_cancellation_status,
        'refund_amount', v_refund_amount,
        'cancellation_penalty_amount', v_penalty_amount,
        'habitacion_id', v_habitacion_id,
        'message', 'Reserva cancelada exitosamente y habitación liberada en el sistema.'
    );
END;
$$;
