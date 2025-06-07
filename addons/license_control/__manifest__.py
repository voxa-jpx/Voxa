{
    'name': 'License Control',
    'version': '1.0.0',
    'summary': 'License Verification and Control',
    'author': 'VOXA',
    'category': 'Tools',
    'depends': ['base'],
    'data': [
        'security/ir.model.access.csv',
        'views/license_view.xml',
        'data/scheduled_actions.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}
