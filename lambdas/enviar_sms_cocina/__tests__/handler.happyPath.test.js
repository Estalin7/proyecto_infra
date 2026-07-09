/**
 * PRUEBA-03
 * Verifica el flujo exitoso del handler: cuando TELEFONO_COCINA está
 * configurada, debe invocar SNS con el número y el mensaje correctos
 * y retornar statusCode 200.
 */

// mockSend debe declararse ANTES del factory de jest.mock
const mockSend = jest.fn().mockResolvedValue({ MessageId: "MSG-XYZ-999" });

jest.mock("@aws-sdk/client-sns", () => {
  const { PublishCommand } = jest.requireActual("@aws-sdk/client-sns");
  return {
    PublishCommand,
    SNSClient: jest.fn(() => ({ send: mockSend })),
  };
});

const { PublishCommand } = require("@aws-sdk/client-sns");
const { handler } = require("../index");

describe("handler — flujo exitoso (happy path)", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.TELEFONO_COCINA = "+51999999999";
  });

  test("PRUEBA-03 — debe invocar SNS con el número y el mensaje correcto, y retornar 200", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    const event = {
      id_pedido: "PED-003",
      mesa: 7,
      items: [
        { nombre: "Arroz con Leche", cantidad: 3 },
        { nombre: "Chicha Morada",   cantidad: 2 },
      ],
    };

    const mensajeEsperado =
      "Nuevo pedido #PED-003 (Mesa 7): 3x Arroz con Leche, 2x Chicha Morada";

    // ── ACT ───────────────────────────────────────────────────────
    const resultado = await handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    expect(mockSend).toHaveBeenCalledTimes(1);

    const commandArg = mockSend.mock.calls[0][0];
    expect(commandArg).toBeInstanceOf(PublishCommand);
    expect(commandArg.input.PhoneNumber).toBe("+51999999999");
    expect(commandArg.input.Message).toBe(mensajeEsperado);

    expect(resultado).toEqual({ statusCode: 200, body: "SMS enviado correctamente" });
  });
});
