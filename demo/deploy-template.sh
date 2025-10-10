#! /bin/bash

TEMPLATE=$1
REGION=${AWS_REGION:-"us-west-2"}
if [ -z "$TEMPLATE" ] ; then
  echo "Usage: $0 <template-file>"
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]] ; then
  echo "Template file $TEMPLATE does not exist"
  exit 1
fi

echo "Deploying AWS FIS template $TEMPLATE"
TEMPLATE_NAME=$(jq -r '.description // "Unnamed Template"' "$TEMPLATE")
echo "Template name: $TEMPLATE_NAME"

# Check if template already exists
EXISTING_TEMPLATE_ID=$(aws fis list-experiment-templates \
  --region "$REGION" \
  --query "experimentTemplates[?description=='$TEMPLATE_NAME'].id" \
  --output text)
if [ -n "$EXISTING_TEMPLATE_ID" ] && [ "$EXISTING_TEMPLATE_ID" != "None" ] ; then
  echo "Template already exists with ID $EXISTING_TEMPLATE_ID, updating it"
  aws fis update-experiment-template \
    --id "$EXISTING_TEMPLATE_ID" \
    --cli-input-json "file://$TEMPLATE" >> /dev/null
  echo "Template updated successfully"
else 
  echo "Template does not exist, creating it"
  aws fis create-experiment-template \
    --cli-input-json "file://$TEMPLATE" >> /dev/null
  echo "Template created successfully"
fi