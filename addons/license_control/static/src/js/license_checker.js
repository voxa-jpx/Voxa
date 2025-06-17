/** @odoo-module **/

import { registry } from "@web/core/registry";
import { Component, onMounted, onWillUnmount, useState } from "@odoo/owl";
import { useService } from "@web/core/utils/hooks";

class LicenseChecker extends Component {
    setup() {
        this.orm = useService("orm");
        this.notification = useService("notification");
        this.state = useState({
            licenseStatus: 'checking',
            lastCheck: null,
            isBlocked: false,
            errorMessage: null,
        });

        onMounted(() => {
            this.checkLicense();
            this.startPeriodicCheck();
        });

        onWillUnmount(() => {
            if (this.intervalId) {
                clearInterval(this.intervalId);
            }
        });
    }

    async checkLicense() {
        try {
            const result = await this.orm.call(
                'license.control',
                'check_system_license',
                []
            );

            this.state.licenseStatus = result ? 'active' : 'invalid';
            this.state.lastCheck = new Date();
            this.state.isBlocked = !result;

            if (!result) {
                this.showLicenseWarning();
            }
        } catch (error) {
            this.state.licenseStatus = 'error';
            this.state.errorMessage = error.message;
            console.error('License check failed:', error);
        }
    }

    startPeriodicCheck() {
        // Verificar licença a cada 30 minutos
        this.intervalId = setInterval(() => {
            this.checkLicense();
        }, 30 * 60 * 1000);
    }

    showLicenseWarning() {
        this.notification.add(
            "Sistema sem licença válida. Algumas funcionalidades podem estar limitadas.",
            {
                title: "Aviso de Licença",
                type: "warning",
                sticky: true,
            }
        );
    }

    async forceVerification() {
        try {
            const licenses = await this.orm.searchRead(
                'license.control',
                [],
                ['id']
            );

            if (licenses.length > 0) {
                await this.orm.call(
                    'license.control',
                    'action_force_verification',
                    [licenses[0].id]
                );
                
                this.notification.add(
                    "Verificação de licença iniciada.",
                    {
                        title: "Licença",
                        type: "info",
                    }
                );
                
                // Aguardar um pouco e verificar novamente
                setTimeout(() => {
                    this.checkLicense();
                }, 3000);
            }
        } catch (error) {
            this.notification.add(
                `Erro ao verificar licença: ${error.message}`,
                {
                    title: "Erro",
                    type: "danger",
                }
            );
        }
    }
}

LicenseChecker.template = "license_control.LicenseChecker";

// Registrar o componente
registry.category("services").add("licenseChecker", {
    start() {
        return new LicenseChecker();
    },
});

// Funções utilitárias globais para verificação de licença
window.voxaLicense = {
    checkLicense: async function() {
        try {
            const response = await fetch('/web/dataset/call_kw', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    jsonrpc: '2.0',
                    method: 'call',
                    params: {
                        model: 'license.control',
                        method: 'check_system_license',
                        args: [],
                        kwargs: {},
                    },
                }),
            });
            
            const result = await response.json();
            return result.result;
        } catch (error) {
            console.error('License check failed:', error);
            return false;
        }
    },

    showLicenseStatus: function() {
        this.checkLicense().then(isValid => {
            const status = isValid ? 'Válida' : 'Inválida';
            const color = isValid ? 'green' : 'red';
            
            console.log(`%cStatus da Licença: ${status}`, `color: ${color}; font-weight: bold;`);
        });
    }
};

// Auto-verificação inicial
document.addEventListener('DOMContentLoaded', function() {
    // Verificar se estamos em uma página do Odoo
    if (document.querySelector('.o_web_client')) {
        setTimeout(() => {
            window.voxaLicense.showLicenseStatus();
        }, 5000);
    }
});