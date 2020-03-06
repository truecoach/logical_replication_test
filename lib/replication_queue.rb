class ReplicationQueue
  class << self
    def produce
      new.produce
    end

    def consume
      new.consume
    end
  end

  def logger
    @_logger ||= Logger.new(STDOUT)
  end

  def sync?
    if ENV['ENABLE_SYNCING'] == 'true'
      logger.info "Starting to sync"
      return true
    else
      logger.info "Syncing disabled"
      return false
    end
  end

  def produce
    return unless sync?

    loop do
      changes = begin
        res = ActiveRecord::Base.connection.execute(
          <<~SQL
            SELECT * FROM pg_logical_slot_get_changes('slot1', NULL, NULL);
          SQL
        )
        logger.info "retrieved: #{res.to_json}"
        JSON.parse(res.to_json)
      rescue StandardError => e
        logger.info "Unable to read slot changes at #{Time.now}: '#{e.message.chomp}'"
        []
      end

      if changes.size == 0
        # logger.info "sending dummy value after 5 seconds"
        logger.info "no changes, waiting 5 seconds"
        sleep 5
        next
        # changes = ['dummy slot change']
        # sleep 5
      end

      batch_messages = changes.map.with_index do |change, index|
        {
          id: index.to_s,
          message_body: change.to_json,
          delay_seconds: 0
        }
      end

      AWS_SQS_REPLICATION_QUEUE.send_messages({ entries: batch_messages })
    end
  end

  def consume
    return unless sync?

    loop do
      messages = AWS_SQS_REPLICATION_QUEUE.receive_messages({
        attribute_names: ["All"],
        max_number_of_messages: 1,
        visibility_timeout: 60,
        wait_time_seconds: 1,
        receive_request_attempt_id: "String",
      })

      if messages.size == 0
        logger.info "no messages @ #{Time.now}"
        sleep 5
      end

      messages.each do |message|
        logger.info ""
        logger.info "Consuming message: #{message.body}"
        logger.info ""

        AWS_SQS_REPLICATION_QUEUE.delete_messages({
          entries: [ # required
            {
              id: message.message_id, # required
              receipt_handle: message.receipt_handle, # required
            },
          ],
        })
      end
    end
  end
end
