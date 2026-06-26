const { Client } = require("pg");
const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");

const lambdaClient = new LambdaClient({});

/**
 * Crea y conecta un cliente PostgreSQL para Aurora.
 * Las credenciales se leen de variables de entorno.
 */
async function conectarBD() {
    const client = new Client({
        host: process.env.AURORA_HOST,
        port: process.env.AURORA_PORT || 5432,
        database: process.env.AURORA_DB_NAME,
        user: process.env.AURORA_USER,
        password: process.env.AURORA_PASSWORD,
        ssl: { rejectUnauthorized: false },
    });

    await client.connect();
    return client;
}

/**
 * Inserta el pedido en la tabla "pedidos".
 */
async function guardarPedido(client, pedido) {
    const { id_pedido, mesa, cliente, total } = pedido;

    const query = `
    INSERT INTO pedidos (id_pedido, mesa, cliente, total, estado, fecha)
    VALUES ($1, $2, $3, $4, $5, NOW())
    ON CONFLICT (id_pedido) DO NOTHING
  `;

    const values = [id_pedido, mesa, cliente, total, "recibido"];

    await client.query(query, values);
}

/**
 * Invoca de forma asincrona la Lambda enviar_sms_cocina,
 * pasandole los items del pedido para armar el mensaje.
 */
async function invocarEnvioSMS(pedido) {
    const payload = {
        id_pedido: pedido.id_pedido,
        mesa: pedido.mesa,
        items: pedido.items,
    };

    const command = new InvokeCommand({
        FunctionName: process.env.LAMBDA_ENVIAR_SMS_ARN,
        InvocationType: "Event", // asincrono, no espera respuesta
        Payload: Buffer.from(JSON.stringify(payload)),
    });

    await lambdaClient.send(command);
}

/**
 * Handler principal.
 * Se invoca via SNS. El cuerpo real del pedido viene en
 * record.Sns.Message como string JSON.
 *
 * Estructura esperada del pedido:
 * {
 *   "id_pedido": "string",
 *   "mesa": "string" | number,
 *   "cliente": "string",
 *   "items": [{ "nombre": "string", "cantidad": number }],
 *   "total": number
 * }
 */
exports.handler = async (event) => {
    console.log("Evento recibido:", JSON.stringify(event));

    let client;

    try {
        client = await conectarBD();

        for (const record of event.Records) {
            const pedido = JSON.parse(record.Sns.Message);

            console.log(`Procesando pedido ${pedido.id_pedido} - mesa ${pedido.mesa}`);

            // 1. Guardar pedido en Aurora
            await guardarPedido(client, pedido);

            // 2. Notificar a cocina via SMS
            await invocarEnvioSMS(pedido);

            console.log(`Pedido ${pedido.id_pedido} procesado correctamente`);
        }

        return { statusCode: 200, body: "Pedidos procesados correctamente" };
    } catch (error) {
        console.error("Error al procesar el pedido:", error);
        // Lanzar el error para que SQS reintente segun la redrive policy
        throw error;
    } finally {
        if (client) {
            await client.end();
        }
    }
};