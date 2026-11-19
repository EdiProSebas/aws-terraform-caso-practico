data "aws_caller_identity" "current" {}

module "kms" {
  source = "../modules/kms"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "financial_storage" {
  source = "../modules/financial-storage"

  bucket_name = "${var.project_name}-${var.environment}-financial-${data.aws_caller_identity.current.account_id}"
  kms_key_arn = module.kms.key_arn
  tags        = local.common_tags
}

module "database" {
  source = "../modules/database"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  kms_key_arn = module.kms.key_arn

  db_name                 = "appdb"
  master_username         = "pgadmin"
  engine_version          = "16.15"
  instance_class          = "db.t4g.medium"
  backup_retention_period = 7

  vpc_cidr             = "10.20.0.0/16"
  private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]

  allowed_security_group_ids = []

  deletion_protection = false
  skip_final_snapshot = true
}

module "secret_access" {
  source = "../modules/secret-access"

  secret_arn        = module.database.master_user_secret_arn
  allowed_role_arns = [data.aws_caller_identity.current.arn]
  tags              = local.common_tags
}
