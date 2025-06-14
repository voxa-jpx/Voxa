# Começa a partir da imagem oficial do Odoo 18
FROM odoo:18.0

# Instalar dependências adicionais do sistema
USER root

# Atualizar repositórios e instalar dependências
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3-dev \
    libxml2-dev \
    libxslt1-dev \
    libevent-dev \
    libsasl2-dev \
    libldap2-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    zlib1g-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# Instalar pacotes Python necessários
RUN pip3 install --break-system-packages \
    python-dotenv==1.0.0 \
    requests==2.31.0 \
    sqlmodel==0.0.14 \
    pydantic==2.5.0 \
    fastapi==0.104.1

# Criar diretórios necessários
RUN mkdir -p /var/lib/odoo/filestore && \
    mkdir -p /var/lib/odoo/sessions && \
    mkdir -p /mnt/extra-addons && \
    chown -R odoo:odoo /var/lib/odoo && \
    chown -R odoo:odoo /mnt/extra-addons

# Copiar configuração personalizada se existir
COPY --chown=odoo:odoo odoo.conf /etc/odoo/odoo.conf

# Voltar para usuário odoo
USER odoo

# Expor porta
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
    CMD curl -f http://localhost:8000/web/health || exit 1

# Comando padrão
CMD ["odoo"]