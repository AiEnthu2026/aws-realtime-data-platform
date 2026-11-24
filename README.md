# AWS Realtime Data Platform

Streams live TfNSW bus vehicle positions (GTFS-realtime) into AWS, built with Terraform and deployed through GitHub Actions using OIDC.

## Architecture (current)

```
EventBridge (1 min, off by default)
  -> Producer Lambda (polls every ~15 s)
       -> Kinesis Data Stream (per-vehicle JSON records)
       -> S3 raw bucket (original protobuf, append-only)
```

## Components

| Component | Purpose |
|---|---|
| Producer Lambda (Python 3.12) | Polls the TfNSW feed, skips unchanged snapshots, writes raw bytes to S3 and one record per vehicle to Kinesis with retries |
| Kinesis Data Stream | 1 provisioned shard, 24 h retention, KMS-encrypted; partition key `vehicle_id` keeps each vehicle's events in order |
| S3 | Separate raw, curated and Athena results buckets; encrypted, public access blocked; Athena results expire after 7 days |
| SSM Parameter Store | TfNSW API key as a SecureString; Terraform holds only a placeholder |
| EventBridge rule | Triggers the producer every minute; disabled unless enabled via Terraform variable |
| IAM | Producer role scoped to one stream, one parameter, one S3 prefix and its own log group |

## Design decisions

| Decision | Reason |
|---|---|
| Parse in the producer, one record per vehicle | Real partition key, per-vehicle ordering, small records |
| Keep raw protobuf in S3 | Exact source copy for reprocessing |
| Kinesis Data Streams over Firehose | Control over processing; multiple consumers and replay |
| SSM SecureString over Secrets Manager | Static key with no rotation needed; free tier |
| GitHub OIDC deploy role | No long-lived AWS keys in CI |
| Separate bootstrap stack | State bucket and CI role survive teardown of the main stack |

## Repository layout

```
terraform/bootstrap   state bucket, GitHub OIDC provider, deploy role (local state)
terraform/main        pipeline resources (S3 remote state)
src/producer          producer Lambda
```

## Setup

1. `terraform/bootstrap`: copy `terraform.tfvars.example` to `terraform.tfvars`, then `terraform init` and `terraform apply`
2. `terraform/main`: create `backend.hcl` with `bucket = "<state-bucket>"`, then `terraform init -backend-config=backend.hcl`
3. Store the TfNSW key: `aws ssm put-parameter --name /rtdp/dev/tfnsw/api-key --type SecureString --value "<key>" --overwrite`
4. Local environment: `python -m venv .venv`, activate it, `pip install -r requirements-dev.txt`

## Build and deploy the producer

```
pip install -r src/producer/requirements.txt --platform manylinux2014_x86_64 --implementation cp --python-version 3.12 --only-binary=:all: --target build/producer
copy src\producer\handler.py build\producer\
terraform -chdir=terraform/main apply
```

## Run

- One-off: `aws lambda invoke --function-name rtdp-dev-producer build/out.json`
- Scheduled: `terraform apply -var="producer_schedule_enabled=true"`; apply without the variable to switch it off

## Cost notes

- The Kinesis shard is billed per hour while the stream exists
- The producer sleeps between polls and that time is billed; run in bursts
- The schedule is off by default

## Known limitations

- The deploy role uses AdministratorAccess; to be scoped down once the resource set is stable
- Single environment (`dev`)
- No private networking (VPC endpoints) yet