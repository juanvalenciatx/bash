#! /bin/bash

# import existing bash aliases
source ~/.bash_aliases

clear

echo
echo '******************** Choose a service to deploy ********************'
echo
echo ' 1) dashboard-service - path [ /v1/dashboard* ]'
echo ' 2) login-service - path [ /v1/auth/login* - /v1/auth/logout ]'
echo ' 3) card-service - path [ /v1/card* ]'
echo ' 4) operations-service - path [ /v1/operations* ]'
echo ' 5) account-service - path [ /v1/account* ]'
echo ' 6) token-service - path [ /v1/token* ]'
echo ' 7) customer-service - path [ /v1/customer* ]'
echo ' 8) operator-service - path [ /v1/operator ]'
echo ' 9) conveniencestore-service - path [ /v1/payment/convenience-store* ]'
echo '10) bankaccounts-service - path [ /v1/bank-accounts ]'
echo

echo 'Please write the SERVICE NUMBER'
echo
read -p 'What do you want to deploy? ' REPLY
echo

updateSource() {
    echo "============ Updating source code ============="
    echo

    # update application source code
    cd ./source/
    git reset --hard
    git pull origin master

    # pull some remote objects from S3
    aws s3 cp s3://bucket-name/vendor.tar.gz . --profile aws_profile
    tar xvf vendor.tar.gz
    rm vendor.tar.gz
    
    cd ../
    echo
    echo "============ Done ============="
}

tagImage() {
    echo "Tagging image $1"
    docker tag api:latest XXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/api:$1
    echo "=================="
    echo
}

buildImage() {
    echo "Building image"
    docker build -t api .
    echo "=================="
    echo
}

ecrLogin() {
    echo "Logging to ECR"
    aws-alias ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin XXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com
    echo "=================="
    echo
}

pushImage() {
    echo "Pushing image to ECR $1"
    docker push XXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/api:$1
    echo "=================="
    echo
}

tagService() {
    echo "Tagging config files"
    pwd
    sed -i "s/NEW_RELIC_APP_NAME=api/NEW_RELIC_APP_NAME=$1/g" Dockerfile
    sed -i "s/service/$1/g" Dockerfile
    sed -i "s/service/$1/g" awslogs.conf
}

forceDeployment() {
    aws-profile ecs update-service --cluster api-cluster-last --service $1 --force-new-deployment --region us-east-1
}

restoreConfig() {
    git checkout Dockerfile
    git checkout awslogs.conf
}

case "$REPLY" in

1)
  service='dashboard-service'
  ;;
2)
  service='login-service'
  ;;
3)
  service='card-service'
  ;;
4)
  service='operations-service'
  ;;
5)
  service='account-service'
  ;;
6)
  service='token-service'
  ;;
7)
  service='customer-service'
  ;;
8)
  service='operator-service'
  ;;
9)
  service='conveniencestore-service'
  ;;
10)
  service='bankaccounts-service'
  ;
*)
  echo 'Invalid service, please write a NUMBER!'
  echo
  exit 1
  ;;

esac

if [ deploy ]
then
  echo "== DEPLOYMENT OF $service STARTED =="
  echo

  updateSource
  tagService $service
  buildImage
  tagImage $service
  ecrLogin
  pushImage $service
  forceDeployment $service
  restoreConfig

  echo
  echo "== DEPLOYMENT OF $service FINISHED =="
  echo
else
  echo 'Nothing to deploy'
  echo
  exit 0
fi
