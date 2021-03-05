import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize('pkg', [
  'kubelet',
  'kubeadm'
])
def test_pkg(host, pkg):
    package = host.package(pkg)

    assert package.is_installed


@pytest.mark.parametrize('svc', [
  'docker',
  'kubelet'
])
def test_svc(host, svc):
    service = host.service(svc)

    assert service.is_running
    assert service.is_enabled


def test_kubectl(host):
    if host.ansible.get_variables()['inventory_hostname'] == 'worker':
        return

    cmd = host.run('kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes')

    assert cmd.rc == 0
    assert 'worker' in cmd.stdout
    assert 'controller' in cmd.stdout
    assert 'Ready' in cmd.stdout
