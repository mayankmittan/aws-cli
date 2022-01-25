#!/bin/bash
CIDR=172.16.0.0/16
aws ec2 create-vpc --cidr-block $CIDR > aws_output.txt
cat aws_output.txt
vpcid='egrep VpcID aws_output.txt | cut -d":" -f2 | sed 's/"//g' |sed 's/.//g' |cut -d" " -f2'
CIDRPublic=172.16.0.0/24
CIDRPrivate=172.16.1.0/24
aws ec2 create-tags \
  --resources "$vpcid" \
  --tags Key=Name,Value="testing"
  
aws ec2 create-subnet --vpc-id $vpcid --cidr-block $CIDRPublic --availibility-zone ap-northeast-3 > aws_output.txt
cat aws_output.txt
pubsubnetid='egrep SubnetID aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 create-subnet --vpc-id $vpcid --cidr-block $CIDRPrivate --availibility-zone ap-south-1a > aws_output.txt
cat aws_output.txt
aws ec2 create-tags \
    --resources "$pubsubnetid"
    --tags Key=Name,Value="public"
    
privsubnetid='egrep SubnetId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 create-internet-gateway > aws_output.txt
cat aws_output.txt
aws ec2 create-tags \
  --resources "$privsubnetid" \
  --tags Key=Name,Value=private"

IGW='egrep InternetGatewayId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 attach-internet-gateway --vpc-id $vpcid --internet-gateway-id $IGW
aws ec2 create-route-table --vpc-ic $vpcid > aws_output.txt
cat aws_output.txt
aws ec2 create-tags \
  --resources "$IGW"
  --tags Key=Name,Value="IGW"
  
RoutePublic='egrep RouteTableId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 create-route-table --vpc-id $vpcid > aws_output.txt
cat aws_output.txt

RoutePrivate='egrep RouteTableId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 associate-route-table --subnet-id $pubsubnetid --route-table-id $RoutePublic
aws ec2 associate-route-table --subnet-id $privsubnetid --route-table-id $RoutePrivate
aws ec2 modify-subnet-attribute --subnet-id $pubsubnetid --map-public-ip-on-launch
aws ec2 create-route --route-table-id $RoutePublic --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW
aws ec2 allocate-address > aws_output.txt
cat aws_output.txt

EIP='egrep AllocationId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'

sleep 20

echo "creating security group for NAT instance"
aws ec2 create-security-group --group-name Natsecurity --description "Nat-1" --vpc-id "$vpcid" > aws_output.txt
SGNat='egrep GroupId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 authorize-security-group-ingress \
  --group-id $SGNat \
  --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp='$CIDRPublic'}]'
  
aws ec2 authorize-security-group-ingress \
  --group-id $SGNat \
  --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp='$CIDRPrivate'}]'
  
 aws ec2 authorize-security-group-ingress \
  --group-id $SGNat \
  --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp='$CIDRPrivate'}]'
  
 aws ec2 authorize-security-group-ingress \
  --group-id $SGNat \
  --ip-permissions IpProtocol=icmp,FromPort=-1,ToPort=-1,IpRanges='[{CidrIp= 0.0.0.0/0}]'
 
 aws ec2 authorize-security-group-engress --group-id $SGNat --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0}]'
 aws ec2 authorize-security-group-engress --group-id $SGNat --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0}]'
 aws ec2 authorize-security-group-engress --group-id $SGNat --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0}]'
 aws ec2 authorize-security-group-engress --group-id $SGNat --ip-permissions IpProtocol=icmp,FromPort=-1,ToPort=-1,IpRanges='[{CidrIp= '$CIDRrivate'}]'

aws ec2 run-instances --image-id ami-000ae30fd003db802 --count 1 --instance-type t2.micro --key-name testing --subnet-id $pubsubnetid --security-group-ids $SGNat > aws_output.txt
cat aws_output.txt

NAT='egrep InstanceId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
echo "waiting for NAT instance"
aws ec2 wait system-status-ok \
  --instance-ids $NAT

aws ec2 modify-instance-attributen--instance-id $NAT --no-source-destination-check
aws ec2 associate-address --instance-id $NAT --allocation-id $EIP > aws_output.txt
cat aws_output.txt
aws ec2 create-route --route-table-id $RoutePrivate --destination-cidr-block 0.0.0.0/ --instance-id $NAT

MYIP='curl -s http://whatismyip.akamai.com/'
echo "creating security groups for public subnet"
aws ec2 crteate-security-group --group-name Pubsecurity --description "public security group" --vpc-id $vpcid > aws_output.txt
SGPub='egrep GroupId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'

aws ec2 aythorize-security-group-ingress \
  --group-id $SGPub \
  --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp='$MYIP/32 }]'
aws ec2 authorize-security-group-ingress \
  --group-id $SGPub \
  --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0./0}]'
aws ec2 authorize-security-group-ingress \
  --group-id $SGPub \
  --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0}]'
  
aws ec2 run-instance --image-id ami-000ae30fd003db802 --count 1 --instance-type t2.micro --key-name testing --subnet-id $pubsubnetid --security-group-ids $SGNat > aws_output.txt
cat aws_output.txt

pubins='egrep InstanceId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'

aws ec2 create-tags \
  --resources "$pubins" \
  --tags Key=Name,Value="public_ins"

aws ec2 allocate-address > aws_output.txt
cat aws_output.txt

eip='egrep AllocationId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 wait system-status-ok \
  --instance-ids $pubins

aws ec2 associate-address --instance-id $pubins --allocation-id $eip > aws_output.txt

echo "creating private instance security group"
aws ec2 create-security-group --groupname Prvsecurity --description "Private security group" --vpc-id $vpcid > aws_output.txt

SGPrv='egrep GroupId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 authorize-security-group-ingress \
  --group-id $SGPrv \
  --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp= 172.16.1.0/24}]'

aws ec2 authorize-security-group-ingress \
  --group-id $SGPrv \
  --ip-permissions IpProtocol=tcp,FromPort=8080,ToPort=8080,IpRanges='[{CidrIp= 172.16.1.0/24}]'
  
aws ec2 run-instance --image-id ami-014bb360092e01bd2 --count 1 --instance-type t2.micro --linuxkey --testing --subnet-id $privsubnetid --security-group-ids $SGNat > aws_output.txt
cat aws_output.txt
privins='egrep InstanceId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 create-tags \
  --resources "$privins" \
  --tags Key=Name,Value="private_ins"
aws ec2 wait system-status-ok \
cat aws_output.txt
