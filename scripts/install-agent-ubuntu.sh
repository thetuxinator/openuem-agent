#!/bin/bash
#
set -e
#variables and config
# Network Settings
SERVER_IP_OR_DOMAIN="your.openuem-server.local"
NATS_PORT="4433"
SFTP_PORT="2022"
VNC_PORT="1443"

# Agent Certificate Data (Paste your block between the quotes)
AGENT_CERT_DATA="-----BEGIN CERTIFICATE-----
MIIByjCCATWgAwIBAgIUHT4vX7p...[SAMPLE AGENT CERTIFICATE DATA]...
MIIByjCCATWgAwIBAgIUHT4vX7p+YjEwDQYJKoZIhvcNAQELBQAwGDEWMBQGA1UE
AwwNT3BlblVETSBSb290IENBMB4XDTI2MDYxNjEzMjcwMFoXDTM2MDYxNDEzMjcw
MFowGDEWMBQGA1UEAwwNT3BlblVETSBBZ2VudDCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBALo0R+...[YOUR REAL CERTIFICATE DATA GOES HERE]...
-----END CERTIFICATE-----"

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

# create certificate files from variables
echo "Deploying Agent Certificate"
echo "$AGENT_CERT_DATA" | sudo tee /etc/openuem-agent/certificates/agent.cer > /dev/null

echo "Deploying Agent Private Key"
echo "$AGENT_KEY_DATA" | sudo tee /etc/openuem-agent/certificates/agent.key > /dev/null

echo "Deploying Certificate Authority (CA) Certificate"
echo "$CA_CERT_DATA" | sudo tee /etc/openuem-agent/certificates/ca.cer > /dev/null

# Only allow root to read
sudo chmod 600 /etc/openuem-agent/certificates/agent.key
sudo chmod 644 /etc/openuem-agent/certificates/*.cer


echo "create config file entries from variables"
INI_FILE="/etc/openuem-agent/openuem.ini"

# Update settings in the config file
sudo sed -i "s|^#\?NATSServers=.*|NATSServers=${SERVER_IP_OR_DOMAIN}:${NATS_PORT}|" "$INI_FILE"
sudo sed -i "s|^#\?SFTPPort=.*|SFTPPort=${SFTP_PORT}|" "$INI_FILE"
sudo sed -i "s|^#\?VNCProxyPort=.*|VNCProxyPort=${VNC_PORT}|" "$INI_FILE"

# compare paths from config with variables
sudo sed -i "s|^#\?AgentCert=.*|AgentCert=/etc/openuem-agent/certificates/agent.cer|" "$INI_FILE"
sudo sed -i "s|^#\?AgentKey=.*|AgentKey=/etc/openuem-agent/certificates/agent.key|" "$INI_FILE"
sudo sed -i "s|^#\?CACert=.*|CACert=/etc/openuem-agent/certificates/ca.cer|" "$INI_FILE"

#enable the service
echo "Starting OpenUEM Agent..."
sudo systemctl daemon-reload
sudo systemctl enable --now openuem-agent

echo "OpenUEM Agent successfully deployed!"
