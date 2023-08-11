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
  provisioned_type_tracking  = "tracking"
  provisioned_type_scheduled = "scheduled"
  # 関数リスト
  function_list = [
    { function_name = "function-1", memory_size = 128, timeout = 3, provisioned = { enable = true, target_alias = "dev", type = local.provisioned_type_tracking, min_capacity = 1, max_capacity = 2 } },
    { function_name = "function-2", memory_size = 128, timeout = 3, provisioned = { enable = true, target_alias = "dev", type = local.provisioned_type_scheduled, min_capacity = 0, max_capacity = 1 } },
  ]
  # エイリアス名
  alias_name = "dev"
}

# Lambdaのソースをzip化
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
  memory_size   = each.value.memory_size

  # 全lambda関数の共通設定
  filename = data.archive_file.main.output_path
  role     = aws_iam_role.lambda.arn
  runtime  = "nodejs16.x"
  handler  = "index.handler"
  publish  = true
}

# Lambda関数URL
resource "aws_lambda_function_url" "main" {
  for_each = aws_lambda_function.main

  function_name      = each.value.function_name
  qualifier          = local.alias_name
  authorization_type = "NONE"
}

# Lambdaエイリアス
resource "aws_lambda_alias" "main" {
  for_each = aws_lambda_function.main

  function_name    = each.value.arn
  function_version = each.value.version
  name             = local.alias_name
  description      = "開発用エイリアス"
}

# Lambdaパーミッション
resource "aws_lambda_permission" "main" {
  for_each = aws_lambda_function.main

  function_name = each.value.function_name
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
}

###################################################################################
# Lambda関連オートスケールソース（スケジュール）
###################################################################################
# スケジュールされたオートスケール用のターゲットを作成
resource "aws_appautoscaling_target" "scheduled" {
  depends_on = [aws_lambda_function.main]

  for_each = { for i in local.function_list : i.function_name => i if can(tobool(i.provisioned.enable)) && strcontains(i.provisioned.type, local.provisioned_type_scheduled) }

  resource_id        = "function:${each.value.function_name}:${local.alias_name}"
  min_capacity       = each.value.provisioned.min_capacity
  max_capacity       = each.value.provisioned.max_capacity
  scalable_dimension = "lambda:function:ProvisionedConcurrency"
  service_namespace  = "lambda"
}

# スケジュールされたスケールイン
resource "aws_appautoscaling_scheduled_action" "scheduled_in" {
  for_each = aws_appautoscaling_target.scheduled

  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  name               = "scheduled_in"
  schedule           = "cron(40 21 ? * * *)"
  timezone           = "Asia/Tokyo"

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.min_capacity
  }
}

# スケジュールされたスケールアウト
resource "aws_appautoscaling_scheduled_action" "scheduled_out" {
  for_each = aws_appautoscaling_target.scheduled

  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  name               = "scheduled_out"
  schedule           = "cron(20 21 ? * * *)"
  timezone           = "Asia/Tokyo"

  scalable_target_action {
    min_capacity = each.value.max_capacity
    max_capacity = each.value.max_capacity
  }
}

###################################################################################
# Lambda関連オートスケールソース（ターゲット追跡型）
###################################################################################
# ターゲット追跡型のオートスケール用のターゲットを作成
resource "aws_appautoscaling_target" "tracking" {
  depends_on = [aws_lambda_function.main]

  for_each = { for i in local.function_list : i.function_name => i if can(tobool(i.provisioned.enable)) && strcontains(i.provisioned.type, local.provisioned_type_tracking) }

  resource_id        = "function:${each.value.function_name}:${local.alias_name}"
  min_capacity       = each.value.provisioned.min_capacity
  max_capacity       = each.value.provisioned.max_capacity
  scalable_dimension = "lambda:function:ProvisionedConcurrency"
  service_namespace  = "lambda"
}
# ターゲット追跡（70%）
resource "aws_appautoscaling_policy" "tracking_policy" {
  for_each = aws_appautoscaling_target.tracking

  resource_id        = each.value.resource_id
  service_namespace  = each.value.service_namespace
  scalable_dimension = each.value.scalable_dimension
  name               = "tracking"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "LambdaProvisionedConcurrencyUtilization"
    }
    target_value = 0.7
  }
}
