# Começa a partir da imagem oficial do Odoo 18
FROM odoo:18.0

# Instalar dependências adicionais do sistema
USER root
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Instalar pacotes Python necessários
RUN pip install --break-system-packages \
    python-dotenv \
    requests \
    sqlmodel \
    pydantic

# Criar diretórios necessários
RUN mkdir -p /var/lib/odoo/filestore && \
    mkdir -p /var/lib/odoo/sessions && \
    chown -R odoo:odoo /var/lib/odoo

# Voltar para usuário odoo
USER odoo

# Expor porta
EXPOSE 8069

# Comando padrão (pode ser sobrescrito no docker-compose)
CMD ["odoo"]