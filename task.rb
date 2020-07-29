require 'springcm-sdk'
require 'oracle_hcm'
require './delivery_log_db.rb'

class Task
  VERSION = '0.1.0'.freeze

  attr_reader :springcm_client

  def initialize
    @springcm_client = create_springcm_client
    @delivery_log_db = DeliveryLogDb.new
  end

  def do
    info
  end

  private

  # Print some info
  def info
    puts <<-INFO
Oracle HCM CLM Sync v#{VERSION}
SpringCM Config:
  Data Center: #{springcm_config['datacenter']}
  Client ID: #{springcm_config['client_id']}
AWS Config:
  SimpleDB Delivery Log Domain: #{aws_config['simpledb']}
    INFO
  end

  def create_springcm_client
    config = springcm_config
    client = Springcm::Client.new(
      config['datacenter'],
      config['client_id'],
      config['client_secret']
    )
    client.connect!
    return client
  end

  def springcm_config
    {
      'datacenter' => ENV['SPRINGCM_DATACENTER'],
      'client_id' => ENV['SPRINGCM_CLIENT_ID'],
      'client_secret' => ENV['SPRINGCM_CLIENT_SECRET']
    }
  end

  def aws_config
    {
      'simpledb' => ENV['SIMPLEDB_DOMAIN']
    }
  end
end
