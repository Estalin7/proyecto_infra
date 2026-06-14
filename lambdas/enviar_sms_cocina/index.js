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
 * Es invocado directamente (InvocationType "Event") por la
 * Lambda procesar_pedido, con el siguiente payload:
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
    console.log("Payload recibido:", JSON.stringify(event));

    try {
        const mensaje = construirMensaje(event);
        const telefonoCocina = process.env.TELEFONO_COCINA;

        if (!telefonoCocina) {
            throw new Error("La variable de entorno TELEFONO_COCINA no esta configurada");
        }

        const command = new PublishCommand({
            PhoneNumber: telefonoCocina,
            Message: mensaje,
        });

        const resultado = await snsClient.send(command);

        console.log(`SMS enviado a cocina. MessageId: ${resultado.MessageId}`);

        return { statusCode: 200, body: "SMS enviado correctamente" };
    } catch (error) {
        console.error("Error al enviar SMS a cocina:", error);
        throw error;
    }
};