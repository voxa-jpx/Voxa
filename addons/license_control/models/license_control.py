from odoo import models, fields, api
import requests
import logging
from dotenv import load_dotenv
import os

# Setup logger
_logger = logging.getLogger(__name__)

# Load .env (fazemos isso uma vez aqui — está ok para o módulo)
load_dotenv()

# Carrega as variáveis de ambiente
API_URL = os.getenv("VOXA_LICENSE_API_URL")
API_KEY = os.getenv("VOXA_LICENSE_API_KEY")

class LicenseControl(models.Model):
    _name = 'license.control'
    _description = 'License Control'

    license_key = fields.Char(string='License Key', required=True)
    expiration_date = fields.Date(string='Expiration Date')
    last_heartbeat = fields.Datetime(string='Last Heartbeat')
    online_status = fields.Selection([
        ('unknown', 'Unknown'),
        ('active', 'Active'),
        ('revoked', 'Revoked'),
        ('expired', 'Expired'),
    ], string='Online Status', default='unknown')

    grace_days = fields.Integer(string='Grace Days', default=5)
    offline_mode = fields.Boolean(string='Offline Mode Enabled', default=False)

    def verify_license_online(self):
        """Verifies license with remote API."""
        self.ensure_one()
        try:
            if not API_URL or not API_KEY:
                _logger.error("API_URL or API_KEY not configured in .env")
                return

            payload = {
                'license_key': self.license_key,
                'domain': self.env['ir.config_parameter'].sudo().get_param('web.base.url'),
                'version': '18.0',
            }

            headers = {
                'Authorization': API_KEY
            }

            response = requests.post(API_URL, json=payload, headers=headers, timeout=10)

            if response.status_code == 200:
                result = response.json()
                _logger.info("License verification result: %s", result)
                self.online_status = result.get('status', 'unknown')
                self.grace_days = result.get('grace_days', 5)
                self.last_heartbeat = fields.Datetime.now()
            else:
                _logger.warning("Failed to verify license: %s", response.text)

        except Exception as e:
            _logger.error("Error verifying license: %s", str(e))
