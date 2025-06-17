#!/bin/bash
set -e

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Voxa Odoo container..."

# Aguardar o banco de dados estar pronto
log "Waiting for database to be ready..."
while ! pg_isready -h "$HOST" -p "5432" -U "$USER" -q; do
    log "Database not ready, waiting..."
    sleep 2
done
log "Database is ready!"

# Verificar se o diretório de addons existe e tem permissões corretas
if [ -d "/mnt/extra-addons" ]; then
    log "Setting up addons directory permissions..."
    find /mnt/extra-addons -type d -exec chmod 755 {} \;
    find /mnt/extra-addons -type f -exec chmod 644 {} \;
fi

# Verificar se existe configuração de licença
if [ -f "/mnt/extra-addons/license_control/__manifest__.py" ]; then
    log "License control module found"
    
    # Criar diretório static se não existir
    mkdir -p /mnt/extra-addons/license_control/static/src/css
    mkdir -p /mnt/extra-addons/license_control/static/src/js
    mkdir -p /mnt/extra-addons/license_control/static/description
    
    log "Static directories created for license module"
fi

# Carregar variáveis de ambiente do arquivo .env se existir
if [ -f "/mnt/extra-addons/.env" ]; then
    log "Loading environment variables from .env file..."
    set -a
    source /mnt/extra-addons/.env
    set +a
fi

# Verificar configuração da API de licença
if [ -n "$VOXA_LICENSE_API_URL" ] && [ -n "$VOXA_LICENSE_API_KEY" ]; then
    log "License API configuration found"
    export VOXA_LICENSE_API_URL
    export VOXA_LICENSE_API_KEY
else
    log "Warning: License API not configured. Set VOXA_LICENSE_API_URL and VOXA_LICENSE_API_KEY"
fi

# Função para atualizar módulo se necessário
update_module_if_needed() {
    local module_name="$1"
    log "Checking if module $module_name needs update..."
    
    # Verificar se o módulo está instalado e precisa de atualização
    if odoo --stop-after-init --log-level=error -d postgres -u "$module_name" --no-http 2>/dev/null; then
        log "Module $module_name updated successfully"
    else
        log "Module $module_name update failed or not needed"
    fi
}

# Se for o primeiro boot, fazer setup inicial
if [ "$1" = "odoo" ] && [ ! -f "/var/lib/odoo/.initialized" ]; then
    log "First boot detected, initializing database..."
    
    # Inicializar banco com módulos básicos
    odoo --stop-after-init --log-level=info -d postgres -i base --no-http
    
    # Instalar módulo de controle de licença se existir
    if [ -f "/mnt/extra-addons/license_control/__manifest__.py" ]; then
        log "Installing license_control module..."
        odoo --stop-after-init --log-level=info -d postgres -i license_control --no-http
    fi
    
    # Marcar como inicializado
    touch /var/lib/odoo/.initialized
    log "Initialization completed"
fi

# Pre-compilar assets se necessário
if [ "$ODOO_ASSETS_PRECOMPILE" = "True" ]; then
    log "Pre-compiling assets..."
    odoo --stop-after-init --log-level=error -d postgres --no-http 2>/dev/null || true
fi

log "Starting Odoo server..."

# Executar comando original
exec "$@"