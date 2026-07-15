/**
 * PRUEBA-01
 * Verifica que el handler construye el mensaje SMS con el formato correcto.
 * La lógica de construirMensaje se valida de forma indirecta: se mockea SNS
 * y se inspecciona el contenido del campo Message enviado al PublishCommand.
 *
 * NOTA: se usa jest.requireActual para mantener el constructor real de
 * PublishCommand; de lo contrario, this.input nunca se asignaría y el
 * assert sobre commandArg.input fallaría.
 */

// mockSend debe declararse ANTES del factory de jest.mock (Jest lo permite
// porque el nombre empieza con "mock").
const mockSend = jest.fn().mockResolvedValue({ MessageId: "MSG-TEST-001" });

jest.mock("@aws-sdk/client-sns", () => {
  // Conservamos PublishCommand real para que this.input sea asignado
  const { PublishCommand } = jest.requireActual("@aws-sdk/client-sns");
  return {
    PublishCommand,
    SNSClient: jest.fn(() => ({ send: mockSend })),
  };
});

const { PublishCommand } = require("@aws-sdk/client-sns");
const { handler } = require("../index");

describe("construirMensaje — verificado a través del handler", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.TELEFONO_COCINA = "+51999999999";
  });

  test("PRUEBA-01 — debe construir el mensaje SMS con el formato correcto", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    const event = {
      id_pedido: "PED-001",
      mesa: 5,
      items: [
        { nombre: "Ceviche",   cantidad: 2 },
        { nombre: "Inca Kola", cantidad: 1 },
      ],
    };

    // ── ACT ───────────────────────────────────────────────────────
    await handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    expect(mockSend).toHaveBeenCalledTimes(1);
    const commandArg = mockSend.mock.calls[0][0];
    expect(commandArg).toBeInstanceOf(PublishCommand);
    expect(commandArg.input.Message).toBe(
      "Nuevo pedido #PED-001 (Mesa 5): 2x Ceviche, 1x Inca Kola"
    );
  });
});
