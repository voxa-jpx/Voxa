#!/bin/bash
set -e

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Voxa Odoo container (WSL mode)..."

# Aguardar o banco de dados estar pronto
log "Waiting for database to be ready..."
while ! pg_isready -h "$HOST" -p "5432" -U "$USER" -q; do
    log "Database not ready, waiting..."
    sleep 2
done
log "Database is ready!"

# Verificar se existe configuração de licença
if [ -f "/mnt/extra-addons/license_control/__manifest__.py" ]; then
    log "License control module found"
    
    # Criar diretórios se não existirem (sem mudar permissões)
    mkdir -p /mnt/extra-addons/license_control/static/src/css 2>/dev/null || true
    mkdir -p /mnt/extra-addons/license_control/static/src/js 2>/dev/null || true
    mkdir -p /mnt/extra-addons/license_control/static/description 2>/dev/null || true
    
    log "Static directories verified"
fi

# Carregar variáveis de ambiente do arquivo .env se existir
if [ -f "/mnt/extra-addons/.env" ]; then
    log "Loading environment variables from .env file..."
    # Usar grep para evitar problemas com line endings
    while IFS='=' read -r key value; do
        if [[ ! -z "$key" && ! "$key" =~ ^# ]]; then
            export "$key=$value"
        fi
    done < <(grep -v '^#' /mnt/extra-addons/.env | grep '=')
fi

# Verificar configuração da API de licença
if [ -n "$VOXA_LICENSE_API_URL" ] && [ -n "$VOXA_LICENSE_API_KEY" ]; then
    log "License API configuration found"
    export VOXA_LICENSE_API_URL
    export VOXA_LICENSE_API_KEY
else
    log "Warning: License API not configured. Set VOXA_LICENSE_API_URL and VOXA_LICENSE_API_KEY"
fi

log "Starting Odoo server..."

# Executar comando original
exec "$@"
