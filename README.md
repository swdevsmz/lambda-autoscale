# lambda-autoscale

## スケジュール

### スケジュールされたオートスケールの設定

#### ターゲットの設定

```
aws application-autoscaling register-scalable-target --service-namespace lambda \
 --resource-id function:function-2:dev --min-capacity 1 --max-capacity 10 \
 --scalable-dimension lambda:function:ProvisionedConcurrency
```

#### スケールアウトの設定

```
aws application-autoscaling put-scheduled-action --service-namespace lambda \
 --scalable-dimension lambda:function:ProvisionedConcurrency \
 --resource-id function:function-2:dev \
 --scheduled-action-name my-one-time-action-scale-out \
 --schedule "at(2019-12-5T20:00:00)" \
 --scalable-target-action MinCapacity=10,MaxCapacity=10
```

#### スケールインの設定

```
aws application-autoscaling put-scheduled-action --service-namespace lambda \
 --scalable-dimension lambda:function:ProvisionedConcurrency \
 --resource-id function:function-2:dev \
 --scheduled-action-name my-one-time-action-scale-in \
 --schedule "at(2019-12-5T01:00:00)" \
 --scalable-target-action MinCapacity=1,MaxCapacity=1
```

###　スケジュールされたオートスケールの削除

#### 対象の確認

```
aws application-autoscaling describe-scaling-policies --service-namespace lambda
```

#### ポリシーの削除

```
aws application-autoscaling delete-scaling-policy --policy-name my-policy --service-namespace lambda --resource-id function:function-2:dev --scalable-dimension lambda:function:ProvisionedConcurrency
```

#### スケジュールアクションの確認

```
aws application-autoscaling describe-scheduled-actions --service-namespace lambda
```

#### スケジュールアクション（スケールアウト）の削除

```
aws application-autoscaling delete-scheduled-action --service-namespace lambda --scheduled-action-name my-one-time-action-scale-out --resource-id function:function-2:dev --scalable-dimension lambda:function:ProvisionedConcurrency
```

#### スケジュールアクション（スケールイン）の削除

```
aws application-autoscaling delete-scheduled-action --service-namespace lambda --scheduled-action-name my-one-time-action-scale-in --resource-id function:function-2:dev --scalable-dimension lambda:function:ProvisionedConcurrency

```

## ターゲット追跡

### ターゲット追跡オートスケールの設定

#### ターゲットの作成

```
aws application-autoscaling register-scalable-target --service-namespace lambda \
 --resource-id function:function-1:dev --min-capacity 1 --max-capacity 10 \
 --scalable-dimension lambda:function:ProvisionedConcurrency
```

#### ポリシーの作成

```
aws application-autoscaling put-scaling-policy --service-namespace lambda \
--scalable-dimension lambda:function:ProvisionedConcurrency --resource-id function:function-1:dev \
--policy-name my-policy --policy-type TargetTrackingScaling \
--target-tracking-scaling-policy-configuration '{ "TargetValue": 0.7, "PredefinedMetricSpecification": {"PredefinedMetricType": "LambdaProvisionedConcurrencyUtilization" }}'
```

### ターゲット追跡オートスケールの削除

#### ポリシーの確認

```
aws application-autoscaling describe-scaling-policies --service-namespace lambda
```

#### ポリシーの削除

```
aws application-autoscaling delete-scaling-policy --policy-name my-policy --service-namespace lambda --resource-id function:function-1:dev --scalable-dimension lambda:function:ProvisionedConcurrency
```

#### ターゲットの確認

```
aws application-autoscaling describe-scalable-targets --service-namespace lambda
```

#### ターゲットの削除

```
aws application-autoscaling deregister-scalable-target --service-namespace lambda --resource-id function:function-1:dev --scalable-dimension lambda:function:ProvisionedConcurrency
```

## 参考 URL

[スケジュール](https://dev.classmethod.jp/articles/lambda-support-scheduled-autoscaling/)

[ターゲット追跡](https://dev.classmethod.jp/articles/lambda-support-provisioned-concurrency-autoscaling-2/)
