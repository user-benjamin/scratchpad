List Running EC2 Instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress,Tags]" --output table

Restart an ECS Service
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment

Fetch Logs from CloudWatch
aws logs tail "/aws/lambda/my-lambda-function" --follow

Get Public IP of an EC2 Instance by Name
INSTANCE_NAME="my-instance"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].PublicIpAddress" --output text

Get the Latest AMI ID
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text

Check IAM Role Permissions
aws iam get-role --role-name MyRole --query "Role.AssumeRolePolicyDocument"

Get Available EKS Clusters
aws eks list-clusters --query "clusters" --output table

Describe a Load Balancer
aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]" --output table

Get Cost and Usage Data
aws ce get-cost-and-usage --time-period Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) --granularity DAILY --metrics "BlendedCost" --output table

S3 Bucket Size Report
aws s3 ls --recursive s3://my-bucket/ | awk '{sum+=$3} END {print "Total Size (Bytes):", sum}'
