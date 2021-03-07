Role Name
=========

Create a kubernetes cluster using kubeadm

Requirements
------------

See requirements.txt

Role Variables
--------------

`kubernetes_token` configures the token used to authenticate nodes

Dependencies
------------

N/A

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: kubernetes }

License
-------

BSD

Author Information
------------------

Tom Doherty <tom@tomdoherty.io>
