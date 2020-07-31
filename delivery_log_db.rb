require 'aws-sdk-simpledb'

class DeliveryLogDb
  attr_reader :sdb, :domain_name, :upload_history

  def initialize(config)
    @sdb = Aws::SimpleDB::Client.new(
      region: config['region'],
      access_key_id: config['access_key_id'],
      secret_access_key: config['secret_access_key']
    )
    @domain_name = config['simpledb_domain']
  end

  def load_history
    @upload_history = {}

    count_results = sdb.select({
      consistent_read: true,
      select_expression: <<-EXPR
        select count(*)
        from #{domain_name}
      EXPR
    })

    count = count_results.items.first.attributes.first.value

    puts "Loading delivery log history from #{domain_name}: #{count} items"

    loop do
      results = sdb.select({
        consistent_read: true,
        select_expression: <<-EXPR
          select delivery_date, clm_document_uid
          from #{domain_name}
        EXPR
      })

      results.items.each { |item|
        upload_history[item.name] = {
          'delivery_date' => get_attribute(item, 'delivery_date'),
          'clm_document_uid' => get_attribute(item, 'clm_document_uid')
        }
      }

      break if results.next_token.nil?
    end
  end

  def log_delivery(record, document)
    puts "Recording delivery of #{record.document_record_id} to SimpleDB..."
    sdb.put_attributes({
      domain_name: domain_name,
      item_name: record.document_record_id.to_s,
      attributes: [
        {
          name: 'delivery_date',
          value: Time.now.iso8601
        },
        {
          name: 'clm_document_uid',
          value: document.uid
        }
      ]
    })
    puts 'Done'
  end

  def uploaded?(document_record_id)
    upload_history.include?(document_record_id.to_s)
  end

  def delivery_date(document_record_id)
    upload_history[document_record_id.to_s]['delivery_date']
  end

  private

  def get_attribute(item, attribute_name)
    item.attributes.select { |attr| attr.name === attribute_name }.first.value
  end
end
