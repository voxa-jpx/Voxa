# -*- coding: utf-8 -*-
{
    'name': 'Voxa License Manager',
    'version': '16.0.1.0.0',
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
        'security/license_security.xml',
        'data/license_data.xml',
        'views/license_views.xml',
        'views/license_dashboard.xml',
        'views/license_menu.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'voxa_license/static/src/css/license_dashboard.css',
            'voxa_license/static/src/js/license_checker.js',
        ],
    },
    'installable': True,
    'auto_install': False,
    'application': True,
    'license': 'LGPL-3',
}