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
| SIMPLEDB_DOMAIN | The SimpleDB domain used to check for previous deliveries and record new ones. |

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

1. Ruby (Rake and Bundler required)
2. AWS CLI
3. Docker
4. AWS IAM credentials (see credentials section below)

### The gist

1. Install [Docker](https://www.docker.com/get-started) and the [AWS CLI](https://aws.amazon.com/cli/)
2. Install [Ruby](https://www.ruby-lang.org/en/downloads/) 2.6, and required development gems:
   ```
   $ gem install bundler --version '~> 2.1'
   $ gem install rake --version '~> 13.0'
   ```
2. Install IAM credentials for this project. See [documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
   for more info. Credentials are available in [Smartsheet](https://app.smartsheet.com/sheets/Hgrj4VHJ7jgp352wRgPxwv3C9HHpCwpqxW6GcgP1?view=grid).
3. Make code changes
4. Login with Docker to the ECR repository (`rake login`)
5. Build container image (`rake build`)
6. Push container image (`rake push`)
7. Update task definition (might not be required if `latest` tag is used)

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

## AWS

The infrastructure supporting this process is detailed below. The CaaS AWS
ECS cluster is used to execute task definitions for this process on a
schedule defined in AWS CloudWatch Events. The containerized code scans
Oracle HCM, and compares against an AWS SimpleDB domain to determine which
files have not yet been transferred to the target environment.

![AWS Infrastructure for Oracle HCM CLM Sync](images/aws.png)

### AWS ECS (Elastic Container Service)

* Cluster: CaaS
* Task definition: JID01171_oracle_hcm_clm_sync_(uat|prod)
* Scheduled event rule: JID01171_oracle_hcm_clm_sync_(uat|prod)

### AWS ECR (Elastic Container Registry)

* Repository: cid00022/jid01171/onepoint_hcm_clm_sync

### AWS SimpleDB

* Domain: oracle_hcm_clm_sync_(uat|prod)
