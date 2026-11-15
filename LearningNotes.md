# Learning notes: AWS services and worker queues

This project uses ElastiCache, Terraform's `random` provider, Secrets Manager, and a Redis-backed worker queue. These notes explain how they fit together in the voting app.

## ElastiCache

Amazon ElastiCache is a managed in-memory data store. This project runs a single-node Redis 7.1 cluster in private subnets. The vote service pushes each vote to Redis; a background worker reads the queue and writes the vote to PostgreSQL. Redis is reachable only from the ECS task security group on port 6379. The application receives the endpoint from Terraform through `REDIS_HOST`.

Redis makes the vote request fast and separates web traffic from database writes. This small single-node setup is for a course project, not high availability: it has no replica or Multi-AZ failover, and queued data is not a durable system of record.

## Terraform random provider

The `random` provider creates a database password using `random_password`. Terraform records the generated result in state so it remains stable across plans and applies; it does not generate a new password each run. Special characters are disabled because this application's .NET connection string is assembled from environment variables and delimiters such as `;` can break it.

The password is sensitive, but Terraform state still contains it. The state bucket therefore needs restricted access and encryption. The password is not an output and is not placed in a task definition's ordinary environment variables.

## Secrets Manager

Secrets Manager stores the generated database password as a secret named `<prefix>-<environment>-db-password`. The ECS task definition references the secret ARN in its `secrets` field. ECS retrieves the value at task startup using the task execution role, whose inline policy grants `secretsmanager:GetSecretValue` for this one secret only.

The application receives `DB_PASSWORD` at runtime. Terraform marks the source value sensitive; the secret value is never deliberately printed or exposed as a Terraform output. The zero-day recovery window allows the same secret name to be created again immediately after a destroy, which is useful for this disposable lab.

## Worker and Redis queue

A worker is a background process that performs work outside the user's web request. Here, the vote service appends JSON messages to Redis list `votes`, and the .NET worker repeatedly removes the oldest item and inserts it into PostgreSQL. The worker has no HTTP port and is not registered with the load balancer. ECS runs it as its own service so it can be deployed and scaled independently from the web services.

The queue decouples accepting a vote from storing it. If the database is briefly slow, the web service can continue enqueueing votes while the worker catches up. This example uses Redis list pop semantics: a message is removed when the worker reads it. A worker crash between removing the message and committing it to PostgreSQL can lose that vote. A production design that needs durable delivery would add acknowledgements/retries or use a queue service with visibility timeouts and a dead-letter queue.

## End-to-end path

1. The browser submits a vote to the `vote` service.
2. `vote` appends it to Redis.
3. The `worker` consumes it and writes it to PostgreSQL on RDS.
4. The `result` service reads PostgreSQL and updates the live results page.

The Terraform resources that implement these pieces are in `infra/cache.tf`, `infra/database.tf`, `infra/iam.tf`, and `infra/ecs.tf`.
