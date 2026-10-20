#!/usr/bin/env bash
# destroy 뒤 "돈 나가는 게 남았나" 확인. 아무것도 안 나오면 통과 (exit 0).
# 예산 알람은 하루 몇 번만 갱신돼서 당일 사고는 못 잡는다. 이게 그날의 마지막 안전장치다.
set -uo pipefail
REGION=${REGION:-ap-northeast-2}
P=${PROJECT:-poc07}
found=0

check() {   # check "이름" 명령...
  local name=$1; shift
  local out; out=$("$@" 2>&1)
  if [ -n "$out" ] && [ "$out" != "None" ]; then
    echo "!! 남아 있음: $name"; echo "$out"; found=1
  else
    echo "ok: $name 없음"
  fi
}

check "EC2 인스턴스" aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Project,Values=$P" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' --output text
check "EBS 볼륨" aws ec2 describe-volumes --region "$REGION" \
  --filters "Name=tag:Project,Values=$P" --query 'Volumes[].[VolumeId,Size,State]' --output text
check "Auto Scaling Group" aws autoscaling describe-auto-scaling-groups --region "$REGION" \
  --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '$P')].AutoScalingGroupName" --output text
check "VPC" aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Project,Values=$P" --query 'Vpcs[].VpcId' --output text
check "Elastic IP (이 실습은 안 만들지만 혹시)" aws ec2 describe-addresses --region "$REGION" \
  --query 'Addresses[].PublicIp' --output text
check "NAT 게이트웨이 (이 실습은 안 만들지만 혹시)" aws ec2 describe-nat-gateways --region "$REGION" \
  --filter "Name=state,Values=available,pending" --query 'NatGateways[].NatGatewayId' --output text

if [ $found -eq 0 ]; then echo "== 통과: 과금 리소스 없음 ($REGION)"; else echo "== 실패: 위 항목 지우기"; fi
exit $found
