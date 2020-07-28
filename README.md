# Oracle HCM CLM Sync

## Description

This script connects to an Oracle HCM account and downloads any document
records for all employees and transfers them to a DocuSign CLM folder and
applies attributes.

## Configuration

This task is designed to be executed in AWS ECS, and as such is configured
with environment variables that can be defined in the task definition's
container config. The following environment variables are required:

| Environment Variable | Description |
|----------------------|-------------|
| SPRINGCM_CLIENT_ID | The client ID used to access SpringCM (DocuSign CLM) via the REST API. |
| SPRINGCM_CLIENT_SECRET | The client secret used to access SpringCM (DocuSign CLM) via the REST API. |
| FILE_LOG_PATH | The path of the CSV file where previously delivered files are recorded (by their DocumentsOfRecordId value). See the Delivery Log section for more details. |

## CLM Delivery & Attributes

Since this solution is designed for Prospect Medical, special consideration
is given to the fact that various entities under the Prospect Medical
umbrella have different routing configurations, including: attribute groups
& attributes, document types, personnel folder structures, etc.

There are four distinct configurations currently:

1. Prospect Medical Systems
2. Alta Hospitals (sometimes referred to as California Hospitals) — except
   Culver City
3. Culver City (part of the California Hospitals system but has a distinct
   attribute group and routing workflow)
4. PMH Hospitals — each of the five hospitals has a distinct folder structure
   and attribute group, although the routing workflow and smart rules in CLM
   are shared.

This project currently only targets entities that fall under #4, specifically:

1. Crozer-Keystone Health System
2. CharterCARE Health Partners
3. Waterbury Hospital
4. East Orange General Hospital
5. Eastern Connecticut Health Network

Since there is no explicit way to retrieve the actual entity that an employee
works at (HCM Work Relationship resources appears to be pointing at parent
companies like Prospect Medical Holdings, Inc. or Prospect Health Access
Network, Inc.), this task is configured to use the first digit of the
employee ID when determining which actual hospital to route to.

| First digit | Hospital |
|-------------|----------|
| 3 | Crozer-Keystone Health System |
|   | CharterCARE Health Partners |
|   | Waterbury Hospital |
|   | East Orange General Hospital |
|   | Eastern Connecticut Health Network |

## Delivery Logging

Container output is available in AWS CloudWatch under the `/caas` log group.
When a file is delivered and tagged, a record is added to AWS SimpleDB.
Future task executions will ignore documents that have been previously
delivered. The structure of a delivery record is as follows:

```json
{
  "document_record_id": "<Unique ID of the HCM document record>",
  "delivery_date": "<Timestamp the upload completed>",
  "clm_document_uid": "<UID of the document in CLM>"
}
```

## Development & Deployment

To work on and/or deploy a new version of this task, you need the following
prerequisites:

1. Ruby
2. Docker
3. AWS IAM credentials (see credentials section below)
4. Rake

### Credentials

To push Docker images and modify ECS task definitions, you'll need an IAM
user with write access to both ECR and ECS. A console-enabled user is helpful
since it's a lot easier to update task definitions in the web console than
with the AWS CLI.

### Code

This application was developed with Ruby 2.6.0, but the newer versions should
work fine, assuming the two main dependencies (oracle_hcm and springcm-sdk
are supported on that version as well.)

### Build

To update the task with new code changes, you first need to build the Docker
image. This can easily be done using Rake:

```rb
$ rake build
$ rake build[my_sync_image,my_tag] # Build with custom image name & tag
```

The `build` task accepts three arguments: the image name, tag, and a boolean
value indicating whether latest should be applied, although this is only
considered if the tag argument is not `latest`—which is the default tag
argument value. For more information on using arguments in Rake tasks, see [here](https://ruby.github.io/rake/doc/rakefile_rdoc.html#label-Tasks+with+Arguments).


### Deploy

Changes are not deployed unless the ECS task definition is updated to use
the appropriate image tag. You can create a new task definition revision from
the AWS ECS web console. The task definition can also use the `latest` tag so
that it always gets the most recent code version, assuming the `latest` tag
was applied to the most recently pushed image.
