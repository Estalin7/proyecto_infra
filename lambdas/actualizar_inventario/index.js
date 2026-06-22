const { Client } = require("pg");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const {
    SecretsManagerClient,
    GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const s3Client = new S3Client({});
const secretsClient = new SecretsManagerClient({});

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
 * Descuenta el stock de cada item del pedido en la tabla
 * "inventario". Se asume que pedido.items trae "nombre" y
 * "cantidad"; el match contra inventario se hace por nombre
 * de producto.
 *
 * NOTA: si tu tabla "inventario" usa producto_id en lugar de
 * nombre para el match, ajusta el WHERE de la query.
 */
async function actualizarStock(client, pedido) {
    for (const item of pedido.items) {
        const query = `
      UPDATE inventario
      SET stock = stock - $1
      WHERE producto_id = (
        SELECT producto_id FROM productos WHERE nombre = $2
      )
    `;

        const values = [item.cantidad, item.nombre];

        await client.query(query, values);
    }
}

/**
 * Genera un JSON resumen del pedido y lo sube al bucket de
 * documentos en S3, bajo la ruta pedidos/<id_pedido>.json
 */
async function guardarResumenS3(pedido) {
    const resumen = {
        id_pedido: pedido.id_pedido,
        mesa: pedido.mesa,
        cliente: pedido.cliente,
        total: pedido.total,
        items: pedido.items,
        fecha: new Date().toISOString(),
    };

    const command = new PutObjectCommand({
        Bucket: process.env.S3_DOCUMENTOS,
        Key: `pedidos/${pedido.id_pedido}.json`,
        Body: JSON.stringify(resumen, null, 2),
        ContentType: "application/json",
    });

    await s3Client.send(command);
}

/**
 * Handler principal.
 * Se invoca via SNS (mismo topic que procesar_pedido).
 * El cuerpo del pedido viene en record.Sns.Message como
 * string JSON, con la misma estructura que en procesar_pedido:
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

            console.log(`Actualizando inventario para pedido ${pedido.id_pedido}`);

            // 1. Descontar stock en Aurora
            await actualizarStock(client, pedido);

            // 2. Guardar resumen del pedido en S3
            await guardarResumenS3(pedido);

            console.log(`Inventario actualizado para pedido ${pedido.id_pedido}`);
        }

        return { statusCode: 200, body: "Inventario actualizado correctamente" };
    } catch (error) {
        console.error("Error al actualizar inventario:", error);
        throw error;
    } finally {
        if (client) {
            await client.end();
        }
    }
};