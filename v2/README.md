# k8s on ec2 using terraform & ansible

# deploy

```shell
$ virtualenv --python=python3 venv
$ . venv/bin/activate
$ pip install -r requirements.txt

$ ( cd aws/global/r53; terraform apply ) # create hosted zone
$ ( cd aws/us-west-2/k8s; terraform apply ) # bring up ec2 instances & elb
$ ./playbook.yml # deploy kubernetes
```

# test

```shell
$ ( cd roles/kubernetes; PY_COLORS=1 molecule test ) # molecule test ansible
$ curl http://k8s.tom.works # test application
```

# cleanup

```shell
$ ( cd aws/us-west-2/k8s; terraform destroy ) # bring up ec2 instances & elb
```
