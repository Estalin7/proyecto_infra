/**
 * PRUEBA-05
 * Verifica que el handler de actualizar_inventario:
 *  1. Ejecuta un UPDATE en Aurora por cada item del pedido con la cantidad y nombre correctos.
 *  2. Sube a S3 un PutObjectCommand con la Key, Bucket y ContentType correctos.
 *  3. Retorna statusCode 200 y cierra la conexión en el bloque finally.
 */

jest.mock("pg");
const mockS3Send  = jest.fn().mockResolvedValue({});

jest.mock("@aws-sdk/client-s3", () => {
  const { PutObjectCommand } = jest.requireActual("@aws-sdk/client-s3");
  return {
    PutObjectCommand,
    S3Client: jest.fn(() => ({ send: mockS3Send })),
  };
});

const { Client }           = require("pg");
const { PutObjectCommand } = require("@aws-sdk/client-s3");

const mockQuery   = jest.fn().mockResolvedValue({});
const mockEnd     = jest.fn().mockResolvedValue({});
const mockConnect = jest.fn().mockResolvedValue({});

Client.mockImplementation(() => ({
  connect: mockConnect,
  query:   mockQuery,
  end:     mockEnd,
}));

const { handler } = require("../index");

describe("handler actualizar_inventario — flujo exitoso", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.AURORA_HOST     = "localhost";
    process.env.AURORA_DB_NAME  = "restaurante";
    process.env.AURORA_USER     = "admin";
    process.env.AURORA_PASSWORD = "secret";
    process.env.S3_DOCUMENTOS   = "mi-bucket-documentos";
  });

  test("PRUEBA-05 — debe descontar el stock en Aurora por cada item y subir el resumen a S3", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    const pedido = {
      id_pedido: "PED-005",
      mesa: 2,
      cliente: "María López",
      items: [
        { nombre: "Tacu Tacu",  cantidad: 1 },
        { nombre: "Pisco Sour", cantidad: 2 },
      ],
      total: 78.50,
    };

    const event = {
      Records: [{ Sns: { Message: JSON.stringify(pedido) } }],
    };

    // ── ACT ───────────────────────────────────────────────────────
    const resultado = await handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    // 1) UPDATE ejecutado una vez por cada item (2 items → 2 llamadas)
    expect(mockQuery).toHaveBeenCalledTimes(2);
    expect(mockQuery).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining("UPDATE inventario"),
      [1, "Tacu Tacu"]
    );
    expect(mockQuery).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining("UPDATE inventario"),
      [2, "Pisco Sour"]
    );

    // 2) PutObjectCommand enviado a S3 con los datos correctos
    expect(mockS3Send).toHaveBeenCalledTimes(1);
    const s3Arg = mockS3Send.mock.calls[0][0];
    expect(s3Arg).toBeInstanceOf(PutObjectCommand);
    expect(s3Arg.input.Bucket).toBe("mi-bucket-documentos");
    expect(s3Arg.input.Key).toBe("pedidos/PED-005.json");
    expect(s3Arg.input.ContentType).toBe("application/json");

    // 3) Respuesta correcta y conexión cerrada
    expect(resultado).toEqual({ statusCode: 200, body: "Inventario actualizado correctamente" });
    expect(mockEnd).toHaveBeenCalledTimes(1);
  });

  test("PRUEBA-08 — debe propagar el error de S3 pero cerrar la conexión a la base de datos", async () => {
    // ── ARRANGE ──────────────────────────────────────────────────
    mockS3Send.mockRejectedValueOnce(new Error("Error de escritura en S3"));

    const pedido = {
      id_pedido: "PED-S3-ERR",
      mesa: 2,
      cliente: "Pedro",
      items: [{ nombre: "Tacu Tacu", cantidad: 1 }],
      total: 30
    };
    const event = {
      Records: [{ Sns: { Message: JSON.stringify(pedido) } }]
    };

    // ── ACT ───────────────────────────────────────────────────────
    const accion = () => handler(event);

    // ── ASSERT ───────────────────────────────────────────────────
    await expect(accion()).rejects.toThrow("Error de escritura en S3");
    expect(mockQuery).toHaveBeenCalledTimes(1); // El stock se debió actualizar primero en DB
    expect(mockEnd).toHaveBeenCalledTimes(1);   // Se cerró la conexión en el finally
  });
});
