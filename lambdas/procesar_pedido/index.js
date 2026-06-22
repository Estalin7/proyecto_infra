const { Client } = require("pg");
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const {
    SecretsManagerClient,
    GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const snsClient = new SNSClient({ region: process.env.AWS_REGION });
const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });

// Cache del secreto para reutilizar en invocaciones subsecuentes (warm starts)
let cachedSecret = null;

/**
 * Obtiene las credenciales de Aurora desde AWS Secrets Manager.
 * Cachea el secreto durante el ciclo de vida de la función.
 */
async function obtenerCredencialesDB() {
    if (cachedSecret) {
        return cachedSecret;
    }

    try {
        const response = await secretsClient.send(
            new GetSecretValueCommand({
                SecretId: process.env.AURORA_SECRET_ARN,
            })
        );

        cachedSecret = JSON.parse(response.SecretString);
        return cachedSecret;
    } catch (error) {
        console.error("Error al obtener credenciales de Secrets Manager:", error.message);
        throw error;
    }
}

/**
 * Crea y conecta un cliente PostgreSQL para Aurora.
 * Las credenciales se obtienen de AWS Secrets Manager.
 * NODE_EXTRA_CA_CERTS está configurado en la Lambda para usar los certificados
 * CA de AWS incluidos en el runtime de Node.js.
 */
async function conectarBD() {
    const credentials = await obtenerCredencialesDB();

    const client = new Client({
        host: credentials.host || process.env.AURORA_HOST,
        port: credentials.port || process.env.AURORA_PORT || 5432,
        database: process.env.AURORA_DB_NAME,
        user: credentials.username,
        password: credentials.password,
        ssl: {
            rejectUnauthorized: true,
        },
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
 * Publica un evento en SNS Topic para notificar que el pedido fue procesado.
 * SNS distribuirá el mensaje a:
 * - Lambda enviar_sms_cocina: envia SMS a cocina
 * - Lambda actualizar_inventario: descuenta stock y guarda en S3
 */
async function publicarEnSNS(pedido) {
    const mensaje = {
        id_pedido: pedido.id_pedido,
        mesa: pedido.mesa,
        cliente: pedido.cliente,
        items: pedido.items,
        total: pedido.total,
        timestamp: new Date().toISOString(),
    };

    const command = new PublishCommand({
        TopicArn: process.env.SNS_TOPIC_ARN,
        Message: JSON.stringify(mensaje),
        Subject: `Pedido ${pedido.id_pedido} procesado`,
    });

    await snsClient.send(command);
    console.log(`Evento publicado en SNS para pedido ${pedido.id_pedido}`);
}

/**
 * Handler principal.
 * Se invoca via SQS (event source mapping).
 * El cuerpo del pedido viene en record.body como string JSON.
 *
 * Estructura esperada del pedido:
 * {
 *   "id_pedido": "string",
 *   "mesa": "string" | number,
 *   "cliente": "string",
 *   "items": [{ "nombre": "string", "cantidad": number }],
 *   "total": number
 * }
 *
 * Retorna batch item failures para reintentar solo los mensajes fallidos.
 */
exports.handler = async (event) => {
    console.log("Evento recibido:", JSON.stringify(event));

    const batchItemFailures = [];
    let client;

    try {
        client = await conectarBD();

        for (const record of event.Records) {
            try {
                const pedido = JSON.parse(record.body);

                console.log(`Procesando pedido ${pedido.id_pedido} - mesa ${pedido.mesa}`);

                // 1. Guardar pedido en Aurora
                await guardarPedido(client, pedido);

                // 2. Publicar evento en SNS (SNS notificará a enviar_sms y actualizar_inventario)
                await publicarEnSNS(pedido);

                console.log(`Pedido ${pedido.id_pedido} procesado correctamente`);
            } catch (error) {
                console.error(`Error al procesar mensaje ${record.messageId}:`, error.message);
                // Reportar este mensaje como fallido para reintento
                batchItemFailures.push({ itemIdentifier: record.messageId });
            }
        }

        return { batchItemFailures };
    } finally {
        if (client) {
            await client.end();
        }
    }
};