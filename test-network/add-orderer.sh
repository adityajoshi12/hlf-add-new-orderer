mkdir orderer
./organizations/fabric-ca/orderer.sh

docker-compose -f docker/orderer.yaml up -d

export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt

export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.key

osnadmin channel join --channelID mychannel --config-block ./channel-artifacts/mychannel.block -o localhost:8053 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"

peer channel fetch config orderer/config_block.pb -o localhost:7050 -c mychannel --tls --cafile $ORDERER_CA

configtxlator proto_decode --input orderer/config_block.pb --type common.Block | jq '.data.data[0].payload.data.config' > orderer/config.json

export TLS_FILE=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt

echo "{\"client_tls_cert\":\"$(cat $TLS_FILE | base64 | awk 1 ORS='')\",\"host\":\"orderer2.example.com\",\"port\":7050,\"server_tls_cert\":\"$(cat $TLS_FILE | base64 | awk 1 ORS='')\"}" > $PWD/orderer/orderer2.json

jq ".channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += [$(cat orderer/orderer2.json)]" orderer/config.json > orderer/modified_config.json


configtxlator proto_encode --input orderer/config.json --type common.Config --output orderer/config.pb

configtxlator proto_encode --input orderer/modified_config.json --type common.Config --output orderer/modified_config.pb



configtxlator compute_update --channel_id mychannel --original orderer/config.pb --updated orderer/modified_config.pb --output orderer/config_update.pb



configtxlator proto_decode --input orderer/config_update.pb --type common.ConfigUpdate --output orderer/config_update.json



echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"mychannel\", \"type\":2}},\"data\":{\"config_update\":"$(cat orderer/config_update.json)"}}}" | jq . > orderer/config_update_in_envelope.json


configtxlator proto_encode --input orderer/config_update_in_envelope.json --type common.Envelope --output orderer/config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"

export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp

export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem



peer channel update -f orderer/config_update_in_envelope.pb -c mychannel -o localhost:7050 --tls true --cafile $ORDERER_CA






