#!/bin/bash
#
set -e
#variables and config
INI_FILE="/etc/openuem-agent/openuem.ini"
# Network Settings
SERVER_IP_OR_DOMAIN="nats.youropenuemurl.example"
NATS_PORT="4433"
SFTP_PORT="2022"
VNC_PORT="1443"
CERT_DIR="/etc/openuem-agent/certificates"
TENANT_ID="2"  # Aus openuem-agent/org
SITE_ID="2"      # Aus openuem-agent/site

# Agent Certificate Data (Paste your block between the quotes)
AGENT_CERT_DATA=""-----BEGIN CERTIFICATE-----
MIIByjCCATWgAwIBAgIUHT4vX7p...[SAMPLE AGENT CERTIFICATE DATA]...
MIIByjCCATWgAwIBAgIUHT4vX7p+YjEwDQYJKoZIhvcNAQELBQAwGDEWMBQGA1UE
AwwNT3BlblVETSBSb290IENBMB4XDTI2MDYxNjEzMjcwMFoXDTM2MDYxNDEzMjcw
MFowGDEWMBQGA1UEAwwNT3BlblVETSBBZ2VudDCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBALo0R+...[YOUR REAL CERTIFICATE DATA GOES HERE]...
-----END CERTIFICATE-----"
"

# Agent Private Key Data
AGENT_KEY_DATA="-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDAujRH...[SAMPLE]
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDAujRHz/vM9K+8
dG2XqY7lXoZQ9K8nZb3...[YOUR REAL PRIVATE KEY GOES HERE]...
-----END PRIVATE KEY-----"

# CA Certificate Data
CA_CERT_DATA="-----BEGIN CERTIFICATE-----
MIIBvTCCASagAwIBAgIUY1N3m...[SAMPLE CA CERTIFICATE DATA]...
MIIBvTCCASagAwIBAgIUY1N3md8xMDQYJKoZIhvcNAQELBQAwGDEWMBQGA1UEAwwN
T3BlblVETSBSb290IENBMB4XDTI2MDYxNjEzMjcwMFoXDTM2MDYxNDEzMjcwMFow
GDEWMBQGA1UEAwwNT3BlblVETSBSb290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAv...[YOUR REAL CA CERTIFICATE DATA GOES HERE]...
-----END CERTIFICATE-----"

#SFTP Certificate Data
SFTP_CERT_DATA="-----BEGIN CERTIFICATE-----
MIIBvTCCASagAwIBAgIUY1N3m...[SAMPLE CA CERTIFICATE DATA]...
MIIBvTCCASagAwIBAgIUY1N3md8xMDQYJKoZIhvcNAQELBQAwGDEWMBQGA1UEAwwN
T3BlblVETSBSb290IENBMB4XDTI2MDYxNjEzMjcwMFoXDTM2MDYxNDEzMjcwMFow
GDEWMBQGA1UEAwwNT3BlblVETSBSb290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAv...[YOUR REAL CA CERTIFICATE DATA GOES HERE]...
-----END CERTIFICATE-----"

#generate a UUID if we don't have one:
if [ -f "$INI_FILE" ] && grep -q "UUID" "$INI_FILE"; then
    SYSTEM_UUID=$(grep "UUID" "$INI_FILE" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')
else
    SYSTEM_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
fi


#
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required but not installed, trying to install" >&2
    apt install -y curl
fi


echo "installing the openuem deb key"
curl -fsSL https://apt.openuem.eu/pgp-key.public | sudo gpg --dearmor -o /usr/share/keyrings/openuem.gpg

#add the repo for amd64
#
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/openuem.gpg] https://apt.openuem.eu stable main" | sudo tee /etc/apt/sources.list.d/openuem.list

sudo apt update -y

apt install -y openuem-agent 

# 3. Zertifikate aus Ihren Variablen schreiben
echo "$AGENT_CERT_DATA" | sudo tee "$CERT_DIR/agent.cer" > /dev/null
echo "$AGENT_KEY_DATA" | sudo tee "$CERT_DIR/agent.key" > /dev/null
echo "$CA_CERT_DATA" | sudo tee "$CERT_DIR/ca.cer" > /dev/null
echo "$SFTP_CERT_DATA" | sudo tee "$CERT_DIR/sftp.cer" > /dev/null

# Clean out any old/commented entries to prevent duplicates
sudo sed -i '/NATSServers=/d' "$INI_FILE"
sudo sed -i '/SFTPPort=/d' "$INI_FILE"
sudo sed -i '/VNCProxyPort=/d' "$INI_FILE"
sudo sed -i '/AgentCert=/d' "$INI_FILE"
sudo sed -i '/AgentKey=/d' "$INI_FILE"
sudo sed -i '/CACert=/d' "$INI_FILE"

echo "create config file entries from variables"

sudo tee "$INI_FILE" > /dev/null << EOF
[Agent]
UUID=${SYSTEM_UUID}
Enabled=true
ExecuteTaskEveryXMinutes=5
Debug=false
DefaultFrequency=60
SFTPPort=${SFTP_PORT}
VNCProxyPort=${VNC_PORT}
TenantID=${TENANT_ID}
SiteID=${SITE_ID}

[NATS]
NATSServers=${SERVER_IP_OR_DOMAIN}:${NATS_PORT}

[Certificates]
CACert=${CERT_DIR}/ca.cer
AgentCert=${CERT_DIR}/agent.cer
AgentKey=${CERT_DIR}/agent.key
SFTPCert=${CERT_DIR}/sftp.cer
EOF

# compare paths from config with variables
sudo sed -i "s|^#\?AgentCert=.*|AgentCert=/etc/openuem-agent/certificates/agent.cer|" "$INI_FILE"
sudo sed -i "s|^#\?AgentKey=.*|AgentKey=/etc/openuem-agent/certificates/agent.key|" "$INI_FILE"
sudo sed -i "s|^#\?CACert=.*|CACert=/etc/openuem-agent/certificates/ca.cer|" "$INI_FILE"

#enable the service
echo "Starting OpenUEM Agent..."
sudo systemctl daemon-reload
sudo systemctl enable --now openuem-agent

sudo chmod 600 /etc/openuem-agent/certificates/agent.key
sudo chmod 644 /etc/openuem-agent/certificates/*.cer
sudo chown -R openuem-agent:openuem-agent /etc/openuem-agent


echo "OpenUEM Agent successfully deployed!"
