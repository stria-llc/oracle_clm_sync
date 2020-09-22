require 'oracle_hcm'
require 'dotenv'
Dotenv.load

class LocationListTask
  attr_reader :hcm

  def initialize
    @hcm = OracleHcm::Client.new(
      ENV['ORACLE_HCM_ENDPOINT'],
      ENV['ORACLE_HCM_USERNAME'],
      ENV['ORACLE_HCM_PASSWORD']
    )
  end

  def do
    workers = hcm.workers
    while !workers.nil?
      workers.items.each do |worker|
        rel = worker.work_relationships.items.first
        if !rel.nil?
          puts rel.assignments.items.first.business_unit
        end
      end
      workers = workers.next
    end
  end
end

LocationListTask.new.do
