from odoo import models, fields, api, exceptions
import requests
import logging
from datetime import datetime, timedelta
import os

# Setup logger
_logger = logging.getLogger(__name__)

class LicenseControl(models.Model):
    _name = 'license.control'
    _description = 'License Control'
    _rec_name = 'license_key'

    license_key = fields.Char(string='License Key', required=True, index=True)
    customer_name = fields.Char(string='Customer Name')
    expiration_date = fields.Date(string='Expiration Date')
    last_heartbeat = fields.Datetime(string='Last Heartbeat')
    
    online_status = fields.Selection([
        ('unknown', 'Unknown'),
        ('active', 'Active'),
        ('revoked', 'Revoked'),
        ('expired', 'Expired'),
    ], string='Online Status', default='unknown', required=True)

    grace_days = fields.Integer(string='Grace Days', default=5)
    offline_mode = fields.Boolean(string='Offline Mode Enabled', default=False)
    
    # Campos de controle
    verification_attempts = fields.Integer(string='Verification Attempts', default=0)
    last_error = fields.Text(string='Last Error')
    is_system_blocked = fields.Boolean(string='System Blocked', default=False)
    
    # Configurações da API
    api_url = fields.Char(string='API URL', compute='_compute_api_config')
    api_key_configured = fields.Boolean(string='API Key Configured', compute='_compute_api_config')

    @api.depends()
    def _compute_api_config(self):
        """Computa as configurações da API a partir das variáveis de ambiente."""
        for record in self:
            record.api_url = os.getenv("VOXA_LICENSE_API_URL", "Not configured")
            record.api_key_configured = bool(os.getenv("VOXA_LICENSE_API_KEY"))

    def _get_api_config(self):
        """Retorna a configuração da API."""
        api_url = os.getenv("VOXA_LICENSE_API_URL")
        api_key = os.getenv("VOXA_LICENSE_API_KEY")
        
        if not api_url or not api_key:
            _logger.error("VOXA_LICENSE_API_URL or VOXA_LICENSE_API_KEY not configured")
            return None, None
            
        return api_url, api_key

    def verify_license_online(self):
        """Verifica a licença com a API remota."""
        self.ensure_one()
        
        api_url, api_key = self._get_api_config()
        if not api_url or not api_key:
            self.last_error = "API not configured properly"
            return False

        try:
            # Preparar payload
            base_url = self.env['ir.config_parameter'].sudo().get_param('web.base.url', 'localhost')
            payload = {
                'license_key': self.license_key,
                'domain': base_url,
                'version': '18.0',
            }

            headers = {
                'Authorization': api_key,
                'Content-Type': 'application/json'
            }

            _logger.info(f"Verifying license {self.license_key} with API at {api_url}")
            
            response = requests.post(api_url, json=payload, headers=headers, timeout=30)
            
            # Incrementar tentativas
            self.verification_attempts += 1

            if response.status_code == 200:
                result = response.json()
                _logger.info(f"License verification successful: {result}")
                
                # Atualizar campos baseado na resposta
                self.online_status = result.get('status', 'unknown')
                self.grace_days = result.get('grace_days', 5)
                self.last_heartbeat = fields.Datetime.now()
                self.last_error = False
                
                # Verificar se o sistema deve ser bloqueado
                if self.online_status in ['revoked', 'expired']:
                    self._check_system_block()
                else:
                    self.is_system_blocked = False
                
                return True
                
            elif response.status_code == 403:
                self.last_error = "Invalid API key or unauthorized"
                _logger.error(f"Unauthorized API access: {response.text}")
                
            elif response.status_code == 404:
                self.online_status = 'unknown'
                self.last_error = "License not found in system"
                _logger.warning(f"License not found: {self.license_key}")
                
            else:
                self.last_error = f"API error: {response.status_code} - {response.text}"
                _logger.warning(f"Failed to verify license: {response.status_code} - {response.text}")

        except requests.exceptions.Timeout:
            self.last_error = "API timeout - enabling offline mode temporarily"
            self.offline_mode = True
            _logger.warning("License verification timeout - offline mode enabled")
            
        except requests.exceptions.ConnectionError:
            self.last_error = "Cannot connect to license API"
            _logger.error("Connection error when verifying license")
            
        except Exception as e:
            self.last_error = f"Unexpected error: {str(e)}"
            _logger.error(f"Error verifying license: {str(e)}")

        return False

    def _check_system_block(self):
        """Verifica se o sistema deve ser bloqueado baseado no status e grace period."""
        if not self.offline_mode and self.online_status in ['revoked', 'expired']:
            if self.last_heartbeat:
                grace_end = self.last_heartbeat + timedelta(days=self.grace_days)
                if datetime.now() > grace_end:
                    self.is_system_blocked = True
                    _logger.critical(f"System blocked due to license status: {self.online_status}")
            else:
                self.is_system_blocked = True

    @api.model
    def verify_all_licenses(self):
        """Método chamado pelo cron para verificar todas as licenças."""
        licenses = self.search([])
        for license_rec in licenses:
            try:
                license_rec.verify_license_online()
                self.env.cr.commit()  # Commit individual para cada licença
            except Exception as e:
                _logger.error(f"Error verifying license {license_rec.license_key}: {str(e)}")
                continue

    @api.model
    def check_system_license(self):
        """Verifica se o sistema está licenciado e pode operar."""
        active_licenses = self.search([
            ('online_status', '=', 'active'),
            ('is_system_blocked', '=', False)
        ])
        
        if not active_licenses:
            # Verificar se existe alguma licença em modo offline
            offline_licenses = self.search([
                ('offline_mode', '=', True),
                ('is_system_blocked', '=', False)
            ])
            
            if not offline_licenses:
                _logger.critical("No valid license found - system operation restricted")
                return False
                
        return True

    def action_force_verification(self):
        """Action para forçar verificação da licença."""
        self.ensure_one()
        success = self.verify_license_online()
        
        if success:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Success',
                    'message': 'License verified successfully!',
                    'type': 'success',
                }
            }
        else:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Error',
                    'message': f'License verification failed: {self.last_error}',
                    'type': 'danger',
                }
            }

    def action_reset_offline_mode(self):
        """Action para resetar modo offline."""
        self.ensure_one()
        self.offline_mode = False
        self.verification_attempts = 0
        return self.action_force_verification()

    @api.model
    def create(self, vals):
        """Override create para verificar licença imediatamente."""
        record = super().create(vals)
        # Verificar licença em background
        self.env.ref('license_control.ir_cron_license_heartbeat').sudo().method_direct_trigger()
        return record