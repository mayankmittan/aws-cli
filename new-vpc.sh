CIDR=11.0.0.0/16
aws ec2 create-vpc --cidr-block $CIDR > aws_output.txt
cat aws_output.txt
vpcid='egrep VpcID aws_output.txt | cut -d":" -f2 | sed 's/"//g' |sed 's/.//g' |cut -d" " -f2'
CIDRPublic=11.0.1.0/24
CIDRPrivate=11.0.2.0/24
aws ec2 create-tags \
  --resources "$vpcid" \
  --tags Key=Name,Value="auto_vpc"
  
aws ec2 create-subnet --vpc-id $vpcid --cidr-block $CIDRPublic --availibility-zone ap-south-1b > aws_output.txt
cat aws_output.txt
pubsubnetid='egrep SubnetID aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 create-subnet --vpc-id $vpcid --cidr-block $CIDRPrivate --availibility-zone ap-south-1a > aws_output.txt
cat aws_output.txt
aws ec2 create-tags \
    --resources "$pubsubnetid"
    --tags Key=Name,Value="pub_subnet"
    
privsubnetid='egrep SubnetId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
aws ec2 create-internet-gateway > aws_output.txt
cat aws_output.txt
aws ec2 create-tags \
  --resources "$privsubnetid" \
  --tags Key=Name,Value=priv_subnet"

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
aws ec2 create-security-group --group-name Natsecurity --description "NAT_security_group" --vpc-id "$vpcid" > aws_output.txt
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

aws ec2 run-instances --image-id ami-000ae30fd003db802 --count 1 --instance-type t2.micro --key-name testing --subnet-id $pubsubnetid --security-   -ids $SGNat > aws_output.txt
cat aws_output.txt

NAT='egrep InstanceId aws_output.txt | cut -d":" -f2 | sed 's/"//g' | sed 's/.//g' | cut -d" " -f2'
