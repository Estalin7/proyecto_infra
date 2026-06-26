#!/bin/bash
# ============================================================
# nameservers.sh
# Actualiza los Name Servers de GoDaddy con los que genera
# Route 53 automáticamente después de terraform apply.
#
# Requiere:
#   - GODADDY_API_KEY y GODADDY_API_SECRET en el entorno
#   - AWS CLI configurado (mismo perfil de Terraform)
#   - jq instalado: sudo apt install jq
#
# Uso:
#   chmod +x nameservers.sh
#   ./nameservers.sh
# ============================================================

set -euo pipefail

DOMAIN="${DOMAIN_NAME:-restaurante-carloncho.com}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"   # opcional; si vacío, lo busca por nombre

# ── 1. Obtener Name Servers de Route 53 ─────────────────────
echo "🔍 Buscando Name Servers de Route 53 para: $DOMAIN"

if [ -z "$HOSTED_ZONE_ID" ]; then
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "$DOMAIN." \
    --query "HostedZones[0].Id" \
    --output text | cut -d'/' -f3)
fi

NS_JSON=$(aws route53 get-hosted-zone \
  --id "$HOSTED_ZONE_ID" \
  --query "DelegationSet.NameServers" \
  --output json)

echo "📋 Name Servers obtenidos:"
echo "$NS_JSON" | jq -r '.[]'

# ── 2. Construir payload para API de GoDaddy ─────────────────
PAYLOAD=$(echo "$NS_JSON" | jq '[.[] | {data: .}]')

# ── 3. Actualizar en GoDaddy ──────────────────────────────────
echo ""
echo "🚀 Actualizando Name Servers en GoDaddy para dominio: $DOMAIN"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/NS/@" \
  -H "Authorization: sso-key ${GODADDY_API_KEY}:${GODADDY_API_SECRET}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "✅ Name Servers actualizados correctamente en GoDaddy."
else
  echo "❌ Error al actualizar en GoDaddy. HTTP Status: $HTTP_STATUS"
  exit 1
fi
