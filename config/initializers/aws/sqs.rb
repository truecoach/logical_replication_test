# AWS access key id and secret are used from ENV. Check .env.example

AWS_SQS_REPLICATION_QUEUE = Aws::SQS::Queue.new(
  ENV.fetch('AWS_SQS_REPLICATION_QUEUE_URL'),
  region: 'us-east-2'
)
