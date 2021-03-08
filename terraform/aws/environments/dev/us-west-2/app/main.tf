terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  /*
     # Commands used to create s3 bucket & dynamodb table - should be derived from directory structure

     aws --region us-west-2 s3api create-bucket --bucket tfstate-dev-us-west-2-app --acl private --create-bucket-configuration LocationConstraint=us-west-2
     aws --region us-west-2 s3api put-bucket-versioning --bucket tfstate-dev-us-west-2-app --versioning-configuration Status=Enabled

     aws --region us-west-2 s3api put-public-access-block --bucket tfstate-dev-us-west-2-app --public-access-block-configuration '{
       "BlockPublicAcls": true,
       "IgnorePublicAcls": true,
       "BlockPublicPolicy": true,
       "RestrictPublicBuckets": true
     }'

     aws --region us-west-2 s3api put-bucket-encryption --bucket tfstate-dev-us-west-2-app --server-side-encryption-configuration '{
       "Rules": [
         {
           "ApplyServerSideEncryptionByDefault": {
             "SSEAlgorithm": "AES256"
           }
         }
       ]
     }'

    aws --region us-west-2 dynamodb create-table --table-name tfstate-dev-us-west-2-app --attribute-definitions '[
      {
        "AttributeName": "LockID",
        "AttributeType": "S"
      }
    ]' --billing-mode PAY_PER_REQUEST --key-schema '[
      {
        "AttributeName": "LockID",
        "KeyType": "HASH"
      }
    ]'
  */

  backend "s3" {
    // environments/dev/us-west-2/app
    bucket         = "tfstate-dev-us-west-2-app"
    dynamodb_table = "tfstate-dev-us-west-2-app"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
  }
}


provider "aws" {
  profile = "default"
  region  = "us-west-2"
}
