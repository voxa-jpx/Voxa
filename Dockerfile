# Começa a partir da imagem oficial do Odoo 18
FROM odoo:18.0

# Instala pacotes Python que você precisa para o seu módulo
RUN pip install --break-system-packages python-dotenv requests
