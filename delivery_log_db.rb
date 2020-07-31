require 'aws-sdk-simpledb'

class DeliveryLogDb
  attr_reader :sdb, :domain_name

  def initialize(config)
    @sdb = Aws::SimpleDB::Client.new(
      access_key_id: config['access_key_id'],
      secret_access_key: config['secret_access_key']
    )
    @domain_name = config['simpledb_domain']
  end
end
