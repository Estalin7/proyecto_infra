/**
 * PRUEBA-04
 * Verifica que el handler de procesar_pedido:
 *  1. Se conecta a Aurora y ejecuta el INSERT con los valores correctos.
 *  2. Invoca la Lambda enviar_sms_cocina de forma asíncrona (InvocationType: "Event").
 *  3. Retorna statusCode 200 y cierra la conexión en el bloque finally.
 */

jest.mock("pg");
const mockLambdaSend = jest.fn().mockResolvedValue({});

jest.mock("@aws-sdk/client-lambda", () => {
  const { InvokeCommand } = jest.requireActual("@aws-sdk/client-lambda");
  return {
    InvokeCommand,
    LambdaClient: jest.fn(() => ({ send: mockLambdaSend })),
  };
});

const { Client }                      = require("pg");
const { InvokeCommand }                = require("@aws-sdk/client-lambda");

const mockQuery   = jest.fn().mockResolvedValue({});
const mockEnd     = jest.fn().mockResolvedValue({});
const mockConnect = jest.fn().mockResolvedValue({});

Client.mockImplementation(() => ({
  connect: mockConnect,
  query:   mockQuery,
  end:     mockEnd,
}));

const { handler } = require("../index");

describe("handler procesar_pedido — flujo exitoso", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.AURORA_HOST           = "localhost";
    process.env.AURORA_DB_NAME        = "restaurante";
    process.env.AURORA_USER           = "admin";
    process.env.AURORA_PASSWORD       = "secret";
    process.env.LAMBDA_ENVIAR_SMS_ARN = "arn:aws:lambda:us-east-1:123456789012:function:enviar_sms_cocina";
  });

  test("PRUEBA-04 — debe insertar el pedido en Aurora e invocar la Lambda de SMS de forma asíncrona", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    const pedido = {
      id_pedido: "PED-004",
      mesa: "12",
      cliente: "Juan Pérez",
      items: [{ nombre: "Caldo de Gallina", cantidad: 2 }],
      total: 45.00,
    };

    const event = {
      Records: [{ Sns: { Message: JSON.stringify(pedido) } }],
    };

    // ── ACT ───────────────────────────────────────────────────────
    const resultado = await handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    // 1) Se conectó a la base de datos
    expect(mockConnect).toHaveBeenCalledTimes(1);

    // 2) Se ejecutó el INSERT con los valores del pedido
    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining("INSERT INTO pedidos"),
      ["PED-004", "12", "Juan Pérez", 45.00, "recibido"]
    );

    // 3) Se invocó la Lambda de SMS en modo asíncrono
    expect(mockLambdaSend).toHaveBeenCalledTimes(1);
    const invokeArg = mockLambdaSend.mock.calls[0][0];
    expect(invokeArg).toBeInstanceOf(InvokeCommand);
    expect(invokeArg.input.InvocationType).toBe("Event");
    expect(invokeArg.input.FunctionName).toBe(
      "arn:aws:lambda:us-east-1:123456789012:function:enviar_sms_cocina"
    );

    // 4) Respuesta correcta
    expect(resultado).toEqual({ statusCode: 200, body: "Pedidos procesados correctamente" });

    // 5) Conexión cerrada en el bloque finally
    expect(mockEnd).toHaveBeenCalledTimes(1);
  });

  test("PRUEBA-06 — debe propagar el error si falla la BD y no invocar el envío de SMS", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    mockConnect.mockRejectedValueOnce(new Error("Conexión rechazada por Aurora"));

    const pedido = {
      id_pedido: "PED-ERR",
      mesa: "1",
      cliente: "Error Test",
      items: [],
      total: 0
    };
    const event = {
      Records: [{ Sns: { Message: JSON.stringify(pedido) } }],
    };

    // ── ACT ───────────────────────────────────────────────────────
    const accion = () => handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    await expect(accion()).rejects.toThrow("Conexión rechazada por Aurora");
    expect(mockLambdaSend).not.toHaveBeenCalled();
  });

  test("PRUEBA-07 — debe procesar todos los pedidos contenidos en el lote del evento", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    const pedido1 = { id_pedido: "PED-BATCH-1", mesa: 1, cliente: "Client A", items: [], total: 10 };
    const pedido2 = { id_pedido: "PED-BATCH-2", mesa: 2, cliente: "Client B", items: [], total: 20 };

    const event = {
      Records: [
        { Sns: { Message: JSON.stringify(pedido1) } },
        { Sns: { Message: JSON.stringify(pedido2) } }
      ]
    };

    // ── ACT ───────────────────────────────────────────────────────
    await handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    expect(mockQuery).toHaveBeenCalledTimes(2);
    expect(mockLambdaSend).toHaveBeenCalledTimes(2);
  });
});
