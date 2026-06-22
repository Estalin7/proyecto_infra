const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const snsClient = new SNSClient({});

/**
 * Construye el texto del SMS a partir de los items del pedido.
 * Ejemplo: "Pedido #123 (Mesa 5): 2x Ceviche, 1x Inca Kola"
 */
function construirMensaje(pedido) {
    const { id_pedido, mesa, items } = pedido;

    const detalleItems = items
        .map((item) => `${item.cantidad}x ${item.nombre}`)
        .join(", ");

    return `Nuevo pedido #${id_pedido} (Mesa ${mesa}): ${detalleItems}`;
}

/**
 * Handler principal.
 * Es invocado por SNS cuando procesar_pedido publica un mensaje al topic.
 * El evento SNS contiene el pedido en record.Sns.Message como string JSON:
 * {
 *   "id_pedido": "string",
 *   "mesa": "string" | number,
 *   "items": [{ "nombre": "string", "cantidad": number }]
 * }
 *
 * El numero de telefono de cocina se obtiene de la variable
 * de entorno TELEFONO_COCINA (formato E.164, ej: +51999999999).
 */
exports.handler = async (event) => {
    console.log("Evento SNS recibido:", JSON.stringify(event));

    try {
        const telefonoCocina = process.env.TELEFONO_COCINA;

        if (!telefonoCocina) {
            throw new Error("La variable de entorno TELEFONO_COCINA no esta configurada");
        }

        for (const record of event.Records) {
            const pedido = JSON.parse(record.Sns.Message);
            console.log(`Procesando pedido ${pedido.id_pedido} para SMS`);

            const mensaje = construirMensaje(pedido);

            const command = new PublishCommand({
                PhoneNumber: telefonoCocina,
                Message: mensaje,
            });

            const resultado = await snsClient.send(command);

            console.log(`SMS enviado a cocina. MessageId: ${resultado.MessageId}`);
        }

        return { statusCode: 200, body: "SMS enviado correctamente" };
    } catch (error) {
        console.error("Error al enviar SMS a cocina:", error);
        throw error;
    }
};