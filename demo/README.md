# Demo — AWS Fault Injection Simulator (FIS)

This folder contains a small AWS FIS demo: IAM permission documents, two FIS experiment templates that target EC2 instances, and helper scripts to deploy templates and run experiments.

Prerequisites
- AWS CLI configured with credentials and a region where FIS is supported (e.g., `us-west-2`).
- Permissions to create IAM roles and FIS experiment templates (IAM:CreateRole, IAM:PutRolePolicy, FIS:CreateExperimentTemplate, etc.).

Important safety note
- The `ec2-terminate` template will terminate EC2 instances. Only use in a non-production, safe test account or with clearly targeted resources.

Folder contents (what each file is and why it's needed)
- `deploy-template.sh`: Script that creates or updates an AWS FIS experiment template using the provided JSON file. Use this to deploy the templates in `templates/ec2/`.
- `start-experiment.sh`: Script to start an experiment from an existing FIS template id and monitor it until completion. It captures logs in `logs/`.
- `permission/fis-role-trust-policy.json`: IAM trust policy allowing the FIS service (`fis.amazonaws.com`) to assume the role. Required so FIS can perform actions in your account on behalf of the experiment.
- `permission/fis-permissions.json`: IAM permissions policy listing the actions the experiment role can perform (EC2 stop/start/terminate, Lambda, S3, FIS actions, etc.). This policy is attached to the role assumed by FIS and restricts what the experiment can do.
- `templates/ec2/ec2-stop.json`: FIS experiment template that chooses EC2 instances by tags and stops a percentage of them (`aws:ec2:stop-instances`).
- `templates/ec2/ec2-terminate.json`: FIS experiment template that chooses EC2 instances by tags and terminates a percentage of them (`aws:ec2:terminate-instances`).

High-level workflow
1. Create an IAM role for FIS with the trust policy in `permission/fis-role-trust-policy.json`.
2. Attach the permissions policy from `permission/fis-permissions.json` to the role.
3. (Optional) Update the `roleArn` value in the template JSON files to point to the created role's ARN.
4. Deploy the FIS templates using `deploy-template.sh` or the `aws fis create-experiment-template` command.
5. Start experiments using the `start-experiment.sh` helper or `aws fis start-experiment`.

Step-by-step commands
1) Create the role (from repository root `demo/`):

```bash
# Replace FISRole with your preferred role name
aws iam create-role \
	--role-name FISRole \
	--assume-role-policy-document file://permission/fis-role-trust-policy.json
```

2) Attach the inline permissions policy from the repo (name it e.g. `FISPermissions`):

```bash
aws iam put-role-policy \
	--role-name FISRole \
	--policy-name FISPermissions \
	--policy-document file://permission/fis-permissions.json
```

Notes:
- The repo `fis-permissions.json` grants several actions on `Resource: "*"`. You can scope those to specific resources (instance ARNs, bucket ARNs) for tighter security.

3) Confirm your role ARN (needed for templates):

```bash
aws iam get-role --role-name FISRole --query 'Role.Arn' --output text
# Example output: arn:aws:iam::123456789012:role/FISRole
```

4) Update templates to use your role ARN (recommended). In the JSON files `templates/ec2/ec2-stop.json` and `templates/ec2/ec2-terminate.json`, set the `roleArn` field to the role ARN from step 3. You can do this with `jq` or edit manually. Example using `jq`:

```bash
ROLE_ARN=$(aws iam get-role --role-name FISRole --query 'Role.Arn' --output text)
jq --arg r "$ROLE_ARN" '.roleArn = $r' templates/ec2/ec2-stop.json > /tmp/ec2-stop.json && mv /tmp/ec2-stop.json templates/ec2/ec2-stop.json
jq --arg r "$ROLE_ARN" '.roleArn = $r' templates/ec2/ec2-terminate.json > /tmp/ec2-terminate.json && mv /tmp/ec2-terminate.json templates/ec2/ec2-terminate.json
```

5) Deploy a template (create or update). From the `demo/` folder you can use the helper script:

```bash
./deploy-template.sh templates/ec2/ec2-stop.json
./deploy-template.sh templates/ec2/ec2-terminate.json
```

What `deploy-template.sh` does:
- Reads the `description` field from the JSON to use as the template name.
- Calls `aws fis list-experiment-templates` to see if a template with that description exists.
- If exists, calls `aws fis update-experiment-template` with the JSON; otherwise calls `aws fis create-experiment-template`.

You can also manually create a template and capture the returned template id:

```bash
# create and store id
TEMPLATE_ID=$(aws fis create-experiment-template --cli-input-json file://templates/ec2/ec2-stop.json --query 'experimentTemplate.id' --output text)
echo "Created template id: $TEMPLATE_ID"
```

6) Start an experiment

Using the `start-experiment.sh` helper (recommended for simple runs):

```bash
./start-experiment.sh <template-id>
# Example: ./start-experiment.sh abcdef12-3456-7890-abcd-EXAMPLE
```

What `start-experiment.sh` does:
- Calls `aws fis start-experiment` and captures the experiment id.
- Loops polling `aws fis get-experiment` until status is `completed`, `stopped`, or `failed`.
- Writes progress and a summary to `logs/experiment-<id>-<timestamp>.log`.

Or start manually:

```bash
aws fis start-experiment --experiment-template-id <template-id>
```

7) Inspect and clean up
- List templates: `aws fis list-experiment-templates`
- Get template: `aws fis get-experiment-template --id <id>`
- Delete template: `aws fis delete-experiment-template --id <id>`
- Stop a running experiment: `aws fis stop-experiment --id <experiment-id>`

Template specifics in this repo
- `templates/ec2/ec2-stop.json`:
	- Description: `ec2-instance-stop`
	- Targets EC2 instances with tags `app=demo` and `chaos-ready=true`.
	- SelectionMode: `PERCENT(35)` — picks ~35% of matched instances.
	- Action: `aws:ec2:stop-instances` (stops selected instances).

- `templates/ec2/ec2-terminate.json`:
	- Description: `ec2-instance-terminate`
	- Targets EC2 instances with the same tags.
	- SelectionMode: `PERCENT(25)` — picks ~25% of matched instances.
	- Action: `aws:ec2:terminate-instances` (permanently terminates selected instances).

Security and safety recommendations
- Test using a small, isolated account or sandbox environment.
- Use tags to limit targets precisely (`chaos-ready`, `env=test`, etc.).
- Prefer `stop` experiments before `terminate` to validate behavior without data loss.
- Narrow IAM permissions to specific resources where possible (avoid `Resource: "*"`).

Troubleshooting
- If `aws fis create-experiment-template` fails with permission errors, ensure the caller (your IAM user) has `fis:CreateExperimentTemplate` and `iam:PassRole` for the role ARN used in the template.
- If experiments fail with `emptyTargetResolutionMode` errors, ensure there are EC2 instances matching the configured tags in the template and the `roleArn` is correct.

Next steps I can help with
- Replace the `roleArn` values in the templates automatically with your account's role.
- Add a safer example template that only adds tags or invokes a Lambda (non-destructive).

---
Files referenced:
- [deploy-template.sh](deploy-template.sh)
- [start-experiment.sh](start-experiment.sh)
- [permission/fis-role-trust-policy.json](permission/fis-role-trust-policy.json)
- [permission/fis-permissions.json](permission/fis-permissions.json)
- [templates/ec2/ec2-stop.json](templates/ec2/ec2-stop.json)
- [templates/ec2/ec2-terminate.json](templates/ec2/ec2-terminate.json)

