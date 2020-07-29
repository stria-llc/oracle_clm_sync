require 'springcm-sdk'
require 'oracle_hcm'
require './delivery_log_db.rb'

class Task
  attr_reader :springcm_client

  def initialize
    @springcm_client = create_springcm_client
    @delivery_log_db = DeliveryLogDb.new
  end

  def do
    puts 'oracle_hcm_clm_sync'
  end

  private

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
end
