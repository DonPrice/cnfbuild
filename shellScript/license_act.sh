#!/bin/sh
# ensure we exit for any error To force push
############################
# Author: Bonny Rais
#
# Donovan Price: Added Reactivate Method, Added copy_api_keys (Lab Sepecific), Added Lab Paths
# Version: stage-5_02
#
############################
set -e
#set -x

CERT_GEN_PATH="/home/ubuntu/cnfbuild/api-server-secrets/ssl"
CWCPATH="/home/ubuntu/api-keys/"
DIGITAL_ASSET_ID=""
LICENSE_STATUS=""
LICENSE_REPORT=""
LICENSE_JWT=""

#lbip=${lbip:="10.1.1.8:30881"}
lbip="$(kubectl get nodes -o json `kubectl get pods -o json | jq -r '.items[] | select(.metadata.name | test("^f5-spk-cwc.*")) | .spec.nodeName'` | jq -r '.status.addresses[0].address'):30881"
CURL_CWC="curl -gsk  --cert  $CWCPATH/client_certificate.pem --key $CWCPATH/client_key.pem --cacert $CWCPATH/ca_certificate.pem "

JWT_FILE=${JWT_FILE:=~/cnfbuild/vals/jwt.txt}
echo $JWT_FILE

copy_api_keys () {
    if [ ! -f $CWCPATH/client_certificate.pem ]; then
        echo "Retrieving Keys from $CERT_GEN_PATH"
        echo "Storing them here $CWCPATH"
        echo "========================================================================="
        echo "== These Keys Need to be retained to allow future interaction with CWC =="
        echo "========================================================================="
        mkdir -p $CWCPATH
        cp $CERT_GEN_PATH/client/certs/client_certificate.pem $CWCPATH
        cp $CERT_GEN_PATH/client/secrets/client_key.pem $CWCPATH
        cp $CERT_GEN_PATH/ca/certs/ca_certificate.pem $CWCPATH 
  fi
}

copy_api_keys

get_license_status() {
    if ! [ -z ${DIGITAL_ASSET_ID} ]; then
        echo "DIGITAL_ASSET_ID: $DIGITAL_ASSET_ID"
        echo "LICENSE_STATUS: $LICENSE_STATUS"
        return
    fi

    IFS=',' read -r DIGITAL_ASSET_ID LICENSE_STATUS <<EOF
$($CURL_CWC https://$lbip/status  | \
          jq -r '. | to_entries | .[] | select((.key == "Status") or (.key == "InitialRegistrationStatus")) | [.value.LicenseDetails.DigitalAssetID, .value.LicenseStatus.State] |join(",")' )
EOF
    echo "DIGITAL_ASSET_ID: $DIGITAL_ASSET_ID"
    echo "LICENSE_STATUS: $LICENSE_STATUS"
    $CURL_CWC https://$lbip/status  |  yq -P
}


get_license_report() {
    if ! [ -z ${LICENSE_REPORT} ]; then
        return
    fi

    get_license_status

    # if [ ! ${LICENSE_STATUS} == ${STS_READY_FOR_REPORT} ]; then
    #     echo "License status is not ready (${LICENSE_STATUS}). Cannot get report. Exiting";
    #     exit -1
    # fi

    LICENSE_REPORT=$($CURL_CWC https://$lbip/report)
    echo "LICENSE_REPORT: $LICENSE_REPORT"
}

get_jwt() {
  if [ ! -z $LICENSE_JWT ]; then
    return
  fi

  if [ ! -f $JWT_FILE ]; then
    echo "cannot locate JWT file in $JWT_FILE. Run the script in the directory containing this file. Exiting"
    exit -1
  fi
  LICENSE_JWT=$(cat $JWT_FILE)
}

get_entitlement_manifest() {
  if [ ! -z "$LICENSE_MANIFEST" ]; then
    return
  fi
  get_license_report
  get_jwt

  echo curl -s -X POST https://product.apis.f5.com/ee/v1/entitlements/telemetry \
    -H "Content-Type: application/json" \
    -H "F5-DigitalAssetId: ${DIGITAL_ASSET_ID}" \
    -H "User-Agent: CNF" \
    -H "Authorization: Bearer $LICENSE_JWT" -d "$LICENSE_REPORT"

  LICENSE_MANIFEST=$(curl -s -X POST https://product.apis.f5.com/ee/v1/entitlements/telemetry \
    -H "Content-Type: application/json" \
    -H "F5-DigitalAssetId: ${DIGITAL_ASSET_ID}" \
    -H "User-Agent: CNF" \
    -H "Authorization: Bearer $LICENSE_JWT" -d "$LICENSE_REPORT" | \
    jq -r '.manifest')

  echo LICENSE_MANIFEST: $LICENSE_MANIFEST
}


send_receipt() {
  get_entitlement_manifest

  $CURL_CWC https://$lbip/receipt -d  "$LICENSE_MANIFEST"

}


disconnected_activate_license() {
  cat <<EOF
Continuing this command will attempt activation by:
1. Confirming that the cluster license status is either
   - Config Report Ready to Download; or
   - Config Report downloaded
2. Download the report
3. Request entitlement from F5 Entitlement server
   *** NOTE *** Ensure that the JWT_FILE value points to the correct JWT file
4. If valid, apply the manifest to the cluster

EOF

  press_enter "If you're not ready to continue, press Ctrl-C, otherwise press Enter"

  get_license_status
  re="^Config Report (Downloaded|Ready to Download)$"
  if ! [[  $LICENSE_STATUS =~ $re ]] ; then
  #if [[ ! "$LICENSE_STATUS" =~ "Config Report (downloaded|Ready to Download)" ]]; then
    echo "License status not in valid state ($LICENSE_STATUS). Exiting"
    exit -1
  fi

  get_entitlement_manifest
  send_receipt

}

reactive_license() {
  get_jwt
  $CURL_CWC https://$lbip/reactivate -d  "$LICENSE_JWT"
}

press_enter(  ) {

  prompt=$1
  [[  -z $prompt ]] && prompt="Press Enter to continue "

  echo ""
  echo -n $prompt
  read
  #clear
}

incorrect_selection() {
  press_enter "Incorrect selection! Press Enter to try again."
}

until [ "$selection" = "0" ]; do
  #clear
  echo " ----- Offline licensing Procedures ------"
  echo "    	a.  disconnected mode activation AIO"
  echo "    	s.  get license status"
  echo "    	m.  get license manifest"
  echo "    	r.  reactivate license"
  echo "    	0.  Exit"
  echo ""
  echo -n "  Enter selection: "
  read selection
  echo ""
  case $selection in
    a ) clear ; disconnected_activate_license ;; 
    m ) clear ; get_entitlement_manifest ;;
    s ) clear ; get_license_status ;;
    r ) clear ; reactive_license ;;
    0 ) clear ; exit ;;
    * ) clear ; incorrect_selection ;;
  esac
done
