# k8s on ec2 using packer, terraform & ansible

# deploy

```shell
# install dependencies
$ virtualenv --python=python3 venv
$ . venv/bin/activate
$ pip install -r requirements.txt
$ curl -sL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.0.4/kustomize_v4.0.4_darwin_amd64.tar.gz | tar xf - 

$ ( cd packer; packer build image.pkr.hcl ) # build ami
$ ( cd terraform/aws/environments/dev/us-west-2/app; terraform init ) # initialise terraform
$ ( cd terraform/aws/environments/dev/us-west-2/app; terraform apply ) # bring up ec2 instances & elb
$ ( cd ansible; ./playbook.yml ) # deploy kubernetes
$ ./kustomize build kubernetes | kubectl --kubeconfig=ansible/kubeconfig.yaml apply -f -
```

# test

```shell
$ ( cd ansible/roles/kubernetes; PY_COLORS=1 molecule test ) # molecule test ansible
$ curl http://k8s.tom.works # test application
```

# cleanup

```shell
$ ( cd terraform/aws/environments/dev/us-west-2/app; terraform destroy ) # bring up ec2 instances & elb
```
