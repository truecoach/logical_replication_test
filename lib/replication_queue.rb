class ReplicationQueue
  class << self
    def produce
      new.produce
    end

    def consume
      new.consume
    end
  end

  def sync?
    return if ENV['ENABLE_SYNCING'] == 'true'

    puts "Syncing disabled"

    false
  end

  def produce
    return unless sync?

    while true do
      changes = begin
        res = ActiveRecord::Base.connection.execute(
          <<~SQL
            SELECT * FROM pg_logical_slot_get_changes('slot1', NULL, NULL);
          SQL
        )
        JSON.parse(res.to_json)
      rescue StandardError => e
        puts "Unable to read slot changes at #{Time.now}: '#{e.message.chomp}'"
        puts "sending dummy value"
        sleep 5
        ['dummy slot value']
      end

      batch_messages = changes.map.with_index do |change, index|
        {
          id: index.to_s,
          message_body: change,
          delay_seconds: 0
        }
      end

      AWS_SQS_REPLICATION_QUEUE.send_messages({ entries: batch_messages })
    end
  end

  def consume
    return unless sync?

    while true do
      messages = AWS_SQS_REPLICATION_QUEUE.receive_messages({
        attribute_names: ["All"],
        max_number_of_messages: 1,
        visibility_timeout: 60,
        wait_time_seconds: 1,
        receive_request_attempt_id: "String",
      })

      if messages.size == 0
        puts "no messages @ #{Time.now}"
        sleep 5
      end

      messages.each do |message|
        puts ""
        puts "Consuming message: #{message.body}"
        puts ""

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
