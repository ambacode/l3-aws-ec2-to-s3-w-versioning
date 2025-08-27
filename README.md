PROJECT TITLE
AWS EC2 To S3 with Versioning

Overview
Stand up aws environment via terraform in which we can ssh to an ec2 instance and perform aws cli actions on a versioned s3 bucket.

Example:
This project demonstrates deploying an AWS VPC using Terraform. It includes a bastion host with AWS CLI installed in a public subnet configured with IAM policy, connected to an S3 bucket via a VPC gateway endpoint.

Architecture
Services used: VPC, Subnets, EC2, S3, IAM, Internet Gateway
Tools: (Terraform, AWS CLI, Git)

Setup Instructions

Prerequisites

AWS free tier account
AWS CLI configured with credentials
Terraform installed

Steps

Initialize Terraform:
terraform init

Review plan:
terraform plan

Apply changes:
terraform apply

Capture outputs:
terraform output ec2_public_ip

Testing/Verification:

SSH to public EC2 instance:
ssh -i ec2_private_key.pem ec2-user@<public_ip>

List the bucket (no output because it's empty):
aws s3 ls s3://my-versioned-bucket-2025133

Put an object into the bucket:
aws s3 cp /tmp/test.txt s3://my-versioned-bucket-2025133/testfolder/file.txt

View the object in the bucket:
aws s3 ls s3://my-versioned-bucket-2025133/testfolder/

Append text to the test.txt file to change it:
echo "some text" >> /tmp/test.txt

Put the same object into the bucket:
aws s3 cp /tmp/test.txt s3://my-versioned-bucket-2025133/testfolder/file.txt

Then view the object in the bucket again (note slightly bigger size):
aws s3 ls s3://my-versioned-bucket-2025133/testfolder/

Then view the versioned objects in the bucket:
aws s3api list-object-versions --bucket my-versioned-bucket-2025133 --prefix testfolder/file.txt

There should be the new and old version of test.txt.

Teardown
terraform destroy

Project Structure
List the file tree so it’s easy to understand. Example:

.
├── main.tf
├── variables.tf
└── README.txt

Key Learnings

Learned how to use Terraform modules to stand up AWS environment in which a compute instance can be accessed via SSH and can perform actions on a versioned S3 bucket.

