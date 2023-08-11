###################################################################################
# Lambda関連IAMロール・ポリシーリソース
###################################################################################
# Policyドキュメント
data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
# IAMロール
resource "aws_iam_role" "lambda" {
  name               = "lambdaurl-function_role"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}
# ロールとポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

###################################################################################
# Lambda関数関連リソース
###################################################################################
locals {
  # 関数リスト
  function_list = [
    { function_name = "function-1", timeout = 3, provisioned = { enable = false, type = "tracking" } },
    { function_name = "function-2", timeout = 3, provisioned = { enable = true, type = "scheduled" } },
  ]
  alias_name = "dev"
}
# TODO
# debug
# output "function_list" {
#   value = local.function_list[0].provisioned.enable
# }

# Archive lambda function
data "archive_file" "main" {
  type        = "zip"
  source_dir  = "function"
  output_path = "${path.module}/.terraform/archive_files/function.zip"
}

# Lambda関数本体
resource "aws_lambda_function" "main" {
  for_each = { for i in local.function_list : i.function_name => i }

  # Lambda関数ごとの設定
  function_name = each.value.function_name
  timeout       = each.value.timeout

  # 全lambda関数の共通設定
  filename = data.archive_file.main.output_path
  role     = aws_iam_role.lambda.arn
  handler  = "index.handler"
  publish  = true
  runtime  = "nodejs16.x"

  # TODO
  # tags = {
  #   provisioned_enable = each.value.provisioned.enable
  #   provisioned_type   = each.value.provisioned.type
  # }
}

# Lambda関数URL
resource "aws_lambda_function_url" "main" {
  for_each = aws_lambda_function.main

  function_name      = each.value.function_name
  qualifier          = local.alias_name
  authorization_type = "NONE"
}

# TODO
# debug
# output "lambda" {
#   # for_each = aws_lambda_function.main
#   # value = aws_lambda_function.main
#   value = aws_lambda_function.main["function-1"].tags.provisioned_enable
# }

# Lambdaエイリアス
resource "aws_lambda_alias" "main" {
  for_each = aws_lambda_function.main

  name             = local.alias_name
  description      = "開発用エイリアス"
  function_name    = each.value.arn
  function_version = each.value.version
}

# lambdaパーミッション
resource "aws_lambda_permission" "allow_cloudwatch" {
  for_each = aws_lambda_function.main

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "events.amazonaws.com"
}

###################################################################################
# Lambda関連オートスケールソース（スケジュール）
###################################################################################
# スケジュールされたオートスケール用のターゲットを作成
resource "aws_appautoscaling_target" "scheduled" {
  depends_on = [aws_lambda_function.main]

  # for_each = { for i in aws_lambda_function.main : i.id => i if can(tobool(i.tags.provisioned_enable)) && strcontains(i.tags.provisioned_type, "scheduled") }
  for_each = { for i in local.function_list : i.function_name => i if can(tobool(i.provisioned.enable)) && strcontains(i.provisioned.type, "scheduled") }

  max_capacity       = 0
  min_capacity       = 0
  resource_id        = "function:${each.value.function_name}:${local.alias_name}"
  scalable_dimension = "lambda:function:ProvisionedConcurrency"
  service_namespace  = "lambda"
}

# スケジュールされたスケールイン
resource "aws_appautoscaling_scheduled_action" "scheduled_in" {
  for_each = aws_appautoscaling_target.scheduled

  name               = "scheduled_in"
  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  schedule           = "cron(0 0 ? * * *)"
  timezone           = "Asia/Tokyo"

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}

# スケジュールされたスケールアウト
resource "aws_appautoscaling_scheduled_action" "scheduled_out" {
  for_each = aws_appautoscaling_target.scheduled

  name               = "scheduled_out"
  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  schedule           = "cron(30 23 ? * * *)"
  timezone           = "Asia/Tokyo"

  scalable_target_action {
    max_capacity = 1
    min_capacity = 1
  }
}

###################################################################################
# Lambda関連オートスケールソース（ターゲット追跡型）
###################################################################################
# ターゲット追跡型のオートスケール用のターゲットを作成
resource "aws_appautoscaling_target" "tracking" {
  depends_on = [aws_lambda_function.main]

  # for_each = { for i in aws_lambda_function.main : i.id => i if can(tobool(i.tags.provisioned_enable)) && strcontains(i.tags.provisioned_type, "tracking") }
  for_each = { for i in local.function_list : i.function_name => i if can(tobool(i.provisioned.enable)) && strcontains(i.provisioned.type, "tracking") }

  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "function:${each.value.function_name}:${local.alias_name}"
  scalable_dimension = "lambda:function:ProvisionedConcurrency"
  service_namespace  = "lambda"
}
# ターゲット追跡（70%）
resource "aws_appautoscaling_policy" "lambda_scale_policy" {
  for_each = aws_appautoscaling_target.tracking

  name               = "tracking"
  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "LambdaProvisionedConcurrencyUtilization"
    }
    target_value = 0.7
  }
}
