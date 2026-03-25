terraform {
  backend "s3" {
    bucket = "zain-eks-tfstate-20260324-2307"
    key    = "eks/terraform.tfstate"
    region = "us-west-2"
  }
}
