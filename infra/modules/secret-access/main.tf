data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "secret_access" {
 statement {
    sid       = "DenyEveryoneElse"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = concat(var.allowed_role_arns, ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"])
    }
    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }

  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  secret_arn = var.secret_arn
  policy     = data.aws_iam_policy_document.secret_access.json
}
