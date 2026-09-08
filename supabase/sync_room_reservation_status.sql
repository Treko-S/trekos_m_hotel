-- ============================================================================
-- HOTEL 3 VAGOS - UTCD
-- SINCRONIZACIÓN AUTOMÁTICA DE ESTADO DE HABITACIONES Y RESERVAS
-- ============================================================================

-- 1. Función disparadora que actualiza el estado de la habitación
CREATE OR REPLACE FUNCTION public.sync_habitacion_estado_on_reserva()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_active_count INTEGER;
    v_has_current_checkin BOOLEAN;
BEGIN
    -- Manejar inserción o actualización
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Si la reserva entra en Check-in o En estadía
        IF NEW.estado IN ('Check-in', 'En estadía', 'En curso', 'Ocupada') THEN
            UPDATE public.habitaciones
            SET estado = 'Ocupada'
            WHERE id = NEW.habitacion_id AND estado != 'Ocupada';

        -- Si la reserva está Confirmada o Garantizada
        ELSIF NEW.estado IN ('Confirmada', 'Garantizada', 'Pendiente', 'Reservada') THEN
            -- Solo marcar Reservada si la habitación no está ya Ocupada
            UPDATE public.habitaciones
            SET estado = 'Reservada'
            WHERE id = NEW.habitacion_id AND estado = 'Disponible';

        -- Si la reserva fue Cancelada o Finalizada
        ELSIF NEW.estado IN ('Cancelada', 'Finalizada') THEN
            -- Verificar si existen otras reservas activas para la misma habitación
            SELECT 
                COUNT(*),
                BOOL_OR(estado IN ('Check-in', 'En estadía', 'En curso', 'Ocupada'))
            INTO v_active_count, v_has_current_checkin
            FROM public.reservas
            WHERE habitacion_id = NEW.habitacion_id
              AND id != NEW.id
              AND estado NOT IN ('Cancelada', 'Finalizada');

            IF v_has_current_checkin THEN
                UPDATE public.habitaciones SET estado = 'Ocupada' WHERE id = NEW.habitacion_id;
            ELSIF v_active_count > 0 THEN
                UPDATE public.habitaciones SET estado = 'Reservada' WHERE id = NEW.habitacion_id;
            ELSE
                UPDATE public.habitaciones SET estado = 'Disponible' WHERE id = NEW.habitacion_id AND estado IN ('Reservada', 'Ocupada');
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    -- Manejar eliminación (DELETE)
    IF (TG_OP = 'DELETE') THEN
        SELECT 
            COUNT(*),
            BOOL_OR(estado IN ('Check-in', 'En estadía', 'En curso', 'Ocupada'))
        INTO v_active_count, v_has_current_checkin
        FROM public.reservas
        WHERE habitacion_id = OLD.habitacion_id
          AND id != OLD.id
          AND estado NOT IN ('Cancelada', 'Finalizada');

        IF v_has_current_checkin THEN
            UPDATE public.habitaciones SET estado = 'Ocupada' WHERE id = OLD.habitacion_id;
        ELSIF v_active_count > 0 THEN
            UPDATE public.habitaciones SET estado = 'Reservada' WHERE id = OLD.habitacion_id;
        ELSE
            UPDATE public.habitaciones SET estado = 'Disponible' WHERE id = OLD.habitacion_id AND estado IN ('Reservada', 'Ocupada');
        END IF;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

-- 2. Crear Trigger en la tabla reservas
DROP TRIGGER IF EXISTS trg_sync_habitacion_estado ON public.reservas;
CREATE TRIGGER trg_sync_habitacion_estado
AFTER INSERT OR UPDATE OF estado, habitacion_id OR DELETE
ON public.reservas
FOR EACH ROW
EXECUTE FUNCTION public.sync_habitacion_estado_on_reserva();

-- 3. Sincronización inicial retroactiva:
-- Habitaciones con reservas activas hoy pasan a 'Reservada' si estaban 'Disponible'
UPDATE public.habitaciones h
SET estado = 'Reservada'
WHERE h.estado = 'Disponible'
  AND EXISTS (
      SELECT 1 FROM public.reservas r
      WHERE r.habitacion_id = h.id
        AND r.estado IN ('Confirmada', 'Garantizada', 'Pendiente', 'Reservada')
  );
