# Permissions for AWS FIS

Commands: 
```bash
aws iam create-
role --role-name FISRole --assume-role-policy-document file://fis-role-trust-policy.json
``` 

```bash
aws iam put-role-policy --role-name FISRole --policy-name FISPermissions --policy-document file://fis-permissions.json
```