# Logical Replication Test

Demo app to query a postgres replication slot and see how it behaves.

Also has a queue producer and consumer, writing and reading those changes to
AWS SQS.

## Dependencies

- Ruby
- Postgres

## Local Setup

```bash
$ bundle install
$ bundle exec rake db:setup db:migrate db:seed
```

## Production Setup

Uses an RDS Postgres instance with a follower. See RDS notes below.

PSQL connection string (password omitted):

```psql
$ psql postgres://postgres:<<password>>@adsteel-investmentday-test.clesovo0kjm6.us-east-2.rds.amazonaws.com:5432/logical_replication_example_production
```

## Queries to manage replication slots

Create a slot (in json format):

```sql
SELECT * FROM pg_create_logical_replication_slot('slot1', 'wal2json');
```

Drop a slot:

```sql
SELECT pg_drop_replication_slot('slot1');
```

View existing slots:

```sql
SELECT * from pg_replication_slots;
```

Consume slot entries:

```sql
SELECT * FROM pg_logical_slot_get_changes('slot1', NULL, NULL);
```

## RDS Specific Considerations

1. Set correct configuration parameters:
  _The default parameter group is not sufficient._

    1. Create a new parameter group (will have all the same defaults as the default group)
    2. Set `rds.logical_replication parameter` to 1
    3. Reboot the database for changes to take effect

2. Add the RDS permission group `rds_replication` to the `postgres` user
3. Create a backup
4. Create a follower

More:
- https://aws.amazon.com/blogs/aws/amazon-rds-for-postgresql-new-minor-versions-logical-replication-dms-and-more/
- https://www.stitchdata.com/docs/integrations/databases/amazon-rds-postgresql/v1#create-replication-slot
