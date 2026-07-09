/**
 * PRUEBA-02
 * Verifica que el handler lanza un error descriptivo cuando la variable
 * de entorno TELEFONO_COCINA no está configurada, sin invocar SNS.
 */

jest.mock("@aws-sdk/client-sns");

const { SNSClient } = require("@aws-sdk/client-sns");

const mockSend = jest.fn();
SNSClient.prototype.send = mockSend;

const { handler } = require("../index");

describe("handler — variable de entorno faltante", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.TELEFONO_COCINA; // asegurar que no está definida
  });

  test("PRUEBA-02 — debe lanzar error si TELEFONO_COCINA no está definida", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    const event = {
      id_pedido: "PED-002",
      mesa: 3,
      items: [{ nombre: "Lomo Saltado", cantidad: 1 }],
    };

    // ── ACT ───────────────────────────────────────────────────────
    const accion = () => handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    await expect(accion()).rejects.toThrow(
      "La variable de entorno TELEFONO_COCINA no esta configurada"
    );
    expect(mockSend).not.toHaveBeenCalled();
  });
});
