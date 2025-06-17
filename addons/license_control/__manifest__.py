# -*- coding: utf-8 -*-
{
    'name': 'Voxa License Manager',
    'version': '18.0.1.0.0',  # Atualizado para Odoo 18
    'category': 'Administration',
    'summary': 'Sistema de gerenciamento de licenças para Voxa',
    'description': """
        Sistema completo de licenças para Voxa:
        - Validação de licenças via API
        - Controle de funcionalidades por licença
        - Monitoramento de uso
        - Dashboard de licenças
    """,
    'author': 'Voxa Team',
    'website': 'https://voxa.com.br',
    'depends': ['base', 'web'],
    'data': [
        'security/ir.model.access.csv',
        'data/scheduled_actions.xml',  # Adicionado arquivo que existe
        'views/license_view.xml',      # Corrigido nome do arquivo
    ],
    'assets': {
        'web.assets_backend': [
            'license_control/static/src/css/license_dashboard.css',  # Nome correto do módulo
            'license_control/static/src/js/license_checker.js',     # Nome correto do módulo
        ],
    },
    'installable': True,
    'auto_install': False,
    'application': True,
    'license': 'LGPL-3',
}