# vmware-migration-stress

The intent of these tests is to provide a method inducing vMotions and node drains while running [openshift-tests](https://github.com/openshift/openshift-tests).

# Requirements 
- Install `tomljson`
- export `KUBECONFIG` to point to the start cluster.  `oc` commands should be operational.
- Desired version of `openshift-tests`


## Obtaining Latest `openshift-tests`
~~~
export KUBECONFIG=/path/to/kubeconfig
podman run --authfile ~/registry-credentials.json --rm --entrypoint cat registry.redhat.io/openshift4/ose-tests:latest /usr/bin/openshift-tests > openshift-tests
chmod +x openshift-tests
~~~

