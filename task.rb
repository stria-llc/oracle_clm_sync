require 'springcm-sdk'
require 'oracle_hcm'
require './delivery_log_db.rb'
require 'dotenv'
Dotenv.load

class Task
  VERSION = '0.1.0'.freeze

  attr_reader :springcm_client, :hcm_client, :delivery_log_db, :clm_upload_paths

  def initialize
    info
    @springcm_client = create_springcm_client
    @hcm_client = create_hcm_client
    @delivery_log_db = DeliveryLogDb.new(aws_config)
  end

  def do
    delivery_log_db.load_history
    transfer_document_records
  end

  private

  def transfer_document_records
    records = hcm_client.document_records(limit: 100)
    while records.items.size > 0
      records.items.each { |document_record|
        transfer_record(document_record)
      }
      records = records.next
    end
  end

  def transfer_record(record)
    id = record.document_record_id
    emp = record.display_name
    emp_id = record.person_number

    if delivery_log_db.uploaded?(id)
      puts "Skipping document record #{id}, delivered #{delivery_log_db.delivery_date(id)}"
      return
    end

    begin
      target_folder = clm_upload_folder_for(record)
      if target_folder.nil?
        puts "Skipping document record #{id}, no assigned CLM location for employee ID #{emp_id}"
      else
        deliver_record(record, target_folder)
      end
    rescue StandardError => error
      puts "Error occurred while processing document record #{id}: #{error}"
    end
  end

  def deliver_record(record, clm_folder)
    attachment = record.attachments.items.first
    content_type = attachment.content_type
    stream = attachment.download

    # Ensure we can upload and tag the file
    case content_type
    when 'application/pdf'
      ext = 'pdf'
      type = :pdf
    when 'image/jpeg'
      ext = 'jpg'
      type = :binary
    when 'image/png'
      ext = 'png'
      type = :binary
    else
      raise "Unhandled content type #{content_type}"
    end
    group_name = attribute_group_name_for(record)
    if group_name.nil?
      raise "Unable to determine target CLM attribute group"
    end

    # Upload document
    document_name = "#{record.person_number}_#{record.document_record_id}_#{attachment.attachment_document_id}.#{ext}"
    puts "Uploading #{document_name}..."
    doc = clm_folder.upload(name: document_name, file: stream, type: type)
    puts 'Done'

    # Set description to title from Oracle HCM
    puts 'Setting description of uploaded file...'
    doc.raw['Description'] = "From Oracle HCM: '#{attachment.title}'"

    # Add attributes
    puts 'Setting attributes...'
    doc.apply_attribute_group(group_name)
    group = doc.attribute_group(group_name)
    group.field('Document Name').value = 'Oracle HCM Document of Record'
    group.field('EMP ID').value = record.person_number

    # Apply updates
    puts 'Applying updates...'
    doc.patch
    puts 'Done'

    delivery_log_db.log_delivery(record, doc)
  end

  def attribute_group_name_for(record)
    emp = hcm_client.worker(id: record.person_id)
    rel = emp.work_relationships(q: 'PrimaryFlag=true').items.first
    asgn = rel.assignments(q: 'PrimaryFlag=true').items.first
    case asgn.business_unit
    when 'CROZER'
      'PMH Employee File - Crozer-Keystone Health System'
    else
      nil
    end
  end

  def clm_upload_folder_for(record)
    emp = hcm_client.worker(id: record.person_id)
    rel = emp.work_relationships(q: 'PrimaryFlag=true').items.first
    asgn = rel.assignments(q: 'PrimaryFlag=true').items.first
    return clm_upload_paths[asgn.business_unit]
  end

  # Print some info
  def info
    puts <<-INFO
Oracle HCM CLM Sync v#{VERSION}
Oracle HCM Config:
  Username: #{hcm_config['username']}
  Endpoint: #{hcm_config['endpoint']}
SpringCM Config:
  Data Center: #{springcm_config['datacenter']}
  Client ID: #{springcm_config['client_id']}
AWS Config:
  SimpleDB Region: #{aws_config['region']}
  SimpleDB Delivery Log Domain: #{aws_config['simpledb_domain']}
  IAM Access Key ID: #{aws_config['access_key_id']}
    INFO
  end

  def create_springcm_client
    config = springcm_config
    client = Springcm::Client.new(
      config['datacenter'],
      config['client_id'],
      config['client_secret']
    )
    puts 'Connecting SpringCM client...'
    client.connect!
    puts 'SpringCM client connection successful'
    puts 'Loading CLM upload folders'
    @clm_upload_paths = {
      'CROZER' => client.folder(path: '/PMH/PMH Hospitals/Crozer-Keystone Health System/Human Resources/_Admin/_CaaS Uploads')
    }
    puts 'Done'
    return client
  end

  def create_hcm_client
    puts 'Configuring HCM client'
    config = hcm_config
    OracleHcm::Client.new(
      config['endpoint'],
      config['username'],
      config['password']
    )
  end

  def hcm_config
    {
      'username' => ENV['ORACLE_HCM_USERNAME'],
      'password' => ENV['ORACLE_HCM_PASSWORD'],
      'endpoint' => ENV['ORACLE_HCM_ENDPOINT']
    }
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
      'region' => ENV['SIMPLEDB_REGION'],
      'simpledb_domain' => ENV['SIMPLEDB_DOMAIN'],
      'access_key_id' => ENV['IAM_ACCESS_KEY_ID'],
      'secret_access_key' => ENV['IAM_SECRET_ACCESS_KEY']
    }
  end
end
