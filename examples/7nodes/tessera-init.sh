#!/usr/bin/env bash

function usage() {
  echo ""
  echo "Usage:"
  echo "    $0 [--nodeCount (default = 7)]"
  echo ""
  echo "Where:"
  echo "    --nodeCount: how many nodes should be created"
  echo ""
  exit -1
}

nodeCount=7
while (( "$#" )); do
    case "$1" in
        --nodeCount)
            nodeCount=$2
            shift 2
            ;;
        *)
            echo "Error: Unsupported command line parameter $1"
            usage
            ;;
    esac
done

echo "[*] Initialising Tessera configuration with ${nodeCount} nodes"

peers=""

for i in $(seq 1 ${nodeCount})
do
    peers+="
        {
            \"url\": \"http://localhost:900${i}\"
        }"
    if [ ${i} -ne ${nodeCount} ]
    then
        peers+=','
    fi
done

currentDir=$(pwd)
for i in $(seq 1 ${nodeCount})
do
    DDIR="${currentDir}/qdata/c${i}"
    mkdir -p ${DDIR}
    mkdir -p qdata/logs
    cp "keys/tm${i}.pub" "${DDIR}/tm.pub"
    cp "keys/tm${i}.key" "${DDIR}/tm.key"
    rm -f "${DDIR}/tm.ipc"

    #change tls to "strict" to enable it (don't forget to also change http -> https)
cat <<EOF > ${DDIR}/tessera-config-09-${i}.json
{
    "useWhiteList": false,
    "jdbc": {
        "username": "sa",
        "password": "",
        "url": "jdbc:h2:${DDIR}/db${i};MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
        "autoCreateTables": true
    },
    "serverConfigs":[
        {
            "app":"ThirdParty",
            "enabled": true,
            "serverAddress": "http://localhost:908${i}",
            "communicationType" : "REST"
        },
        {
            "app":"Q2T",
            "enabled": true,
             "serverAddress":"unix:${DDIR}/tm.ipc",
            "communicationType" : "REST"
        },
        {
            "app":"P2P",
            "enabled": true,
            "serverAddress":"http://localhost:900${i}",
            "sslConfig": {
                "tls": "OFF",
                "generateKeyStoreIfNotExisted": true,
                "serverKeyStore": "${DDIR}/server${i}-keystore",
                "serverKeyStorePassword": "quorum",
                "serverTrustStore": "${DDIR}/server-truststore",
                "serverTrustStorePassword": "quorum",
                "serverTrustMode": "TOFU",
                "knownClientsFile": "${DDIR}/knownClients",
                "clientKeyStore": "${DDIR}/client${i}-keystore",
                "clientKeyStorePassword": "quorum",
                "clientTrustStore": "${DDIR}/client-truststore",
                "clientTrustStorePassword": "quorum",
                "clientTrustMode": "TOFU",
                "knownServersFile": "${DDIR}/knownServers"
            },
            "communicationType" : "REST"
        }
    ],
    "peer": [
        ${peers}
    ],
    "keys": {
        "passwords": [],
        "keyData": [
            {
                "privateKeyPath": "${DDIR}/tm.key",
                "publicKeyPath": "${DDIR}/tm.pub"
            }
        ]
    },
    "alwaysSendTo": []
}
EOF

# Enclave configurations

cat <<EOF > ${DDIR}/tessera-config-enclave-09-${i}.json
{
    "useWhiteList": false,
    "jdbc": {
        "username": "sa",
        "password": "",
        "url": "jdbc:h2:${DDIR}/db${i};MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
        "autoCreateTables": true
    },
    "serverConfigs":[
        {
            "app":"ENCLAVE",
            "enabled": true,
            "serverAddress": "http://localhost:918${i}",
            "communicationType" : "REST"
        },
        {
            "app":"ThirdParty",
            "enabled": true,
            "serverAddress": "http://localhost:908${i}",
            "communicationType" : "REST"
        },
        {
            "app":"Q2T",
            "enabled": true,
             "serverAddress":"unix:${DDIR}/tm.ipc",
            "communicationType" : "REST"
        },
        {
            "app":"P2P",
            "enabled": true,
            "serverAddress":"http://localhost:900${i}",
            "sslConfig": {
                "tls": "OFF"
            },
            "communicationType" : "REST"
        }
    ],
    "peer": [
        ${peers}
    ]
}
EOF

cat <<EOF > ${DDIR}/enclave-09-${i}.json
{
    "serverConfigs":[
        {
            "app":"ENCLAVE",
            "enabled": true,
            "serverAddress": "http://localhost:918${i}",
            "communicationType" : "REST"
        }
    ],
    "keys": {
        "passwords": [],
        "keyData": [
            {
                "privateKeyPath": "${DDIR}/tm.key",
                "publicKeyPath": "${DDIR}/tm.pub"
            }
        ]
    },
    "alwaysSendTo": []
}
EOF

done