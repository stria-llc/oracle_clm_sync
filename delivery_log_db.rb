require 'aws-sdk-simpledb'

class DeliveryLogDb
  attr_reader :sdb, :domain_name

  def initialize
    @sdb = Aws::SimpleDB::Client.new(
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    @domain_name = ENV['AWS_SIMPLEDB_DOMAIN']
  end
end
