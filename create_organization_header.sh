#!/bin/bash
#set -x
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[[ "$#" -ne 2 ]] && {
  echo "Usage : $(basename "$0") --project_id <Google Cloud Project ID >"
  exit 1
}
[[ "$1" = "--project_id" ]] && export PROJECT_ID=$2

export AUTH_ORG_FILE="authorized_organization.json"
export ORG_NAME=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" |awk -F@ '{print $2}')
export ORG_ID=$(gcloud organizations list --format=[no-heading] | grep ^${ORG_NAME} | awk '{print $2}')

function check_empty_variables() {
  variables=(ORG_ID PROJECT_ID)

  for variable in "${variables[@]}"; do
    if [ -z "${!variable}" ]; then
      printf "ERROR: Required variable $variable is either empty or unset.\n\n"
      printf "Update required vairable $variable with a value and run script again. \n\n"
      exit
    fi
  done

}

function check_exit() {
  # Check if the exit code is 0
  if [[ $? -ne 0 ]]; then
    echo "Error occurred"
    exit 1
  fi
}



function create_strict_org_header() {
cat <<EOF >$HOME/authorized_organization.json.template
{
"resources": ["organizations/ORG_ID"],
 "options": "strict"
}
EOF
check_exit
cp $HOME/authorized_organization.json.template $HOME/$AUTH_ORG_FILE
check_exit
sed -i '' "s/ORG_ID/${ORG_ID}/" $HOME/$AUTH_ORG_FILE
check_exit
BASE64_ORG_HEADER=`cat $HOME/$AUTH_ORG_FILE | base64`
check_exit
echo "BASE64 HEADER for curl command: $BASE64_ORG_HEADER"
echo ""
}

function create_api_call () {
TOKEN=$(gcloud auth print-access-token)
set -x
# Make a request that includes the organization restriction header; this call makes a request to the logging API for a project within the same organization listed in the header
curl -H "X-Goog-Allowed-Resources: ${BASE64_ORG_HEADER}" -X POST -d '{"resourceNames":["projects/'${PROJECT_ID}'"]}' -H 'Content-Type: application/json' -H "Authorization: Bearer ${TOKEN}" "https://logging.googleapis.com/v2/entries:list"
set +x
check_exit
}


create_strict_org_header
create_api_call