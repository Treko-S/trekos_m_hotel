import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") || "";
const BREVO_SENDER_EMAIL = Deno.env.get("BREVO_SENDER_EMAIL") || "mckakucorpii@gmail.com";
const BREVO_SENDER_NAME = Deno.env.get("BREVO_SENDER_NAME") || "Hotel 3 Vagos";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EmailPayload {
  to: string;
  type: "new_booking" | "payment_receipt" | "invoice";
  bookingCode: string;
  guestName: string;
  roomNumber?: string;
  roomType?: string;
  checkIn?: string;
  checkOut?: string;
  totalAmount?: number;
  paidAmount?: number;
  remainingAmount?: number;
  paymentMethod?: string;
  transactionRef?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: EmailPayload = await req.json();

    const formatGs = (n?: number) => {
      if (n === undefined || n === null) return "0 Gs.";
      return new Intl.NumberFormat("es-PY").format(Math.round(n)) + " Gs.";
    };

    const isPayment = payload.type === "payment_receipt";
    const subject = isPayment
      ? `Comprobante de Pago / Seña - ${payload.bookingCode} | Hotel 3 Vagos`
      : `Confirmación de Reserva ${payload.bookingCode} | Hotel 3 Vagos`;

    const total = payload.totalAmount || 0;
    const paid = payload.paidAmount || 0;
    const remaining = payload.remainingAmount ?? Math.max(0, total - paid);
    const iva10 = Math.round(total / 11);
    const gravada10 = Math.round(total / 1.10);

    const html = `
      <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); color: #ffffff; padding: 26px 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #D4AF37; letter-spacing: 1px;">HOTEL 3 VAGOS</h1>
          <p style="margin: 4px 0 0; font-size: 12px; color: #94A3B8;">Hospitalidad & Excelencia - UTCD Asunción</p>
        </div>

        <div style="padding: 24px;">
          <div style="background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 12px 16px; margin-bottom: 20px;">
            <div style="font-size: 11px; color: #64748B;">RUC: <strong>80092341-2</strong> | Timbrado SET: <strong>16789423</strong> (Vig. 31/12/2026)</div>
            <div style="font-size: 13px; font-weight: 700; color: #0F172A; margin-top: 2px;">
              ${isPayment ? "RECIBO OFICIAL DE PAGO / SEÑA" : "CONFIRMACIÓN OFICIAL DE RESERVA & FOLIO"}
            </div>
          </div>

          <p style="font-size: 14px; color: #334155; margin-bottom: 16px;">
            Hola <strong>${payload.guestName}</strong>,<br>
            ${isPayment
              ? "Hemos registrado exitosamente tu abono/seña. A continuación encontrarás el detalle actualizado de tu folio de cuenta:"
              : "Tu reserva ha sido confirmada con éxito. A continuación encontrarás el desglose oficial de tu estadía:"}
          </p>

          <table style="width: 100%; font-size: 13px; border-collapse: collapse; margin-bottom: 20px;">
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Código de Reserva:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 700; color: #0F172A;">${payload.bookingCode}</td>
            </tr>
            ${payload.roomNumber ? `
              <tr style="border-bottom: 1px solid #E2E8F0;">
                <td style="padding: 8px 0; color: #64748B;">Habitación:</td>
                <td style="padding: 8px 0; text-align: right; font-weight: 600;">Hab. ${payload.roomNumber} (${payload.roomType || 'Estándar'})</td>
              </tr>
            ` : ""}
            ${payload.checkIn ? `
              <tr style="border-bottom: 1px solid #E2E8F0;">
                <td style="padding: 8px 0; color: #64748B;">Estadía:</td>
                <td style="padding: 8px 0; text-align: right;">${payload.checkIn} al ${payload.checkOut || ''}</td>
              </tr>
            ` : ""}
            ${payload.transactionRef ? `
              <tr style="border-bottom: 1px solid #E2E8F0;">
                <td style="padding: 8px 0; color: #64748B;">N° Operación / Transacción:</td>
                <td style="padding: 8px 0; text-align: right; font-family: monospace;">${payload.transactionRef}</td>
              </tr>
            ` : ""}
            ${payload.paymentMethod ? `
              <tr style="border-bottom: 1px solid #E2E8F0;">
                <td style="padding: 8px 0; color: #64748B;">Método de Pago:</td>
                <td style="padding: 8px 0; text-align: right;">${payload.paymentMethod}</td>
              </tr>
            ` : ""}
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Monto Total Estadía:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 700;">${formatGs(total)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0; background: #F0FDF4;">
              <td style="padding: 8px 6px; color: #166534; font-weight: 600;">Monto Abonado / Seña:</td>
              <td style="padding: 8px 6px; text-align: right; font-weight: 700; color: #15803D;">-${formatGs(paid)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B; font-weight: 700;">Saldo Pendiente:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 800; color: ${remaining > 0 ? '#DC2626' : '#15803D'}; font-size: 15px;">
                ${formatGs(remaining)}
              </td>
            </tr>
          </table>

          <div style="background: #F8FAFC; border-radius: 8px; padding: 12px; font-size: 11.5px; color: #64748B; margin-bottom: 20px;">
            <strong>Liquidación Tributaria SET:</strong> Gravadas 10%: ${formatGs(gravada10)} | IVA 10%: ${formatGs(iva10)} | Exentas: 0 Gs.
          </div>

          <div style="text-align: center; color: #94A3B8; font-size: 12px; line-height: 1.5;">
            <p style="margin: 0 0 4px;">Hotel 3 Vagos - Asunción, Paraguay</p>
            <p style="margin: 0; font-size: 11px;">Recepción 24/7 disponible para asistirte en todo momento.</p>
          </div>
        </div>
      </div>
    `;

    // Despacho oficial vía Brevo API v3
    const brevoRes = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": BREVO_API_KEY.trim(),
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify({
        sender: { name: BREVO_SENDER_NAME, email: BREVO_SENDER_EMAIL },
        to: [{ email: payload.to, name: payload.guestName || "Huésped" }],
        subject: subject,
        htmlContent: html,
      }),
    });

    const brevoData = await brevoRes.json();
    return new Response(JSON.stringify({ ...brevoData, provider: "Brevo" }), {
      status: brevoRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
