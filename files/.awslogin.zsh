awslogin() {
  if [[ "$1" == "localstack" ]]; then
    export AWS_PROFILE="localstack"
    export AWS_ACCESS_KEY_ID="test"
    export AWS_SECRET_ACCESS_KEY="test"
  else
    command awslogin "$@" && export AWS_PROFILE="enterprise-digitalization-${1}"
  fi
}

awslogout() {
  if [[ "$AWS_PROFILE" != "localstack" ]]; then
    aws sso logout
  fi
  unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
}