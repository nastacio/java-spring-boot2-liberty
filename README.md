# java-spring-boot2-liberty

## Pipeline Setup

https://kabanero.io/guides/curating-pipelines

Cloned from https://github.com/My-Appsody-Org/kabanero-pipelines

namespace=demo
oc -n ${namespace} apply -f ci/tekton/pipelines-build-pipeline.yaml 
oc -n ${namespace} apply -f ci/tekton/pipelines-build-task.yaml 
oc -n ${namespace} adm policy add-scc-to-user privileged -z pipelines-index
oc -n ${namespace} apply -f pipelines/sample-helper-files/pipelines/pipelines-build-git-resource.yaml
oc -n ${namespace} apply -f pipelines/sample-helper-files/pipelines-build-pipeline-run.yaml


oc get sa kabanero-pipeline -o yaml  | grep "secrets:" -A 5 | grep "kabanero" | cut -d " " -f 3 | \
while read line
do 
    oc get secret $line -o yaml  | sed "s|namespace: kabanero|namespace: demo|g" | kubectl apply -f -
done

oc -n ${namespace} secrets link pipelines-index kabanero-pipeline-token-v25sl

 oc -n ${namespace} delete --ignore-not-found -f pipelines/sample-helper-files/pipelines-build-pipeline-run.yaml
 sleep 5
 oc -n ${namespace} apply -f pipelines/sample-helper-files/pipelines-build-pipeline-run.yaml

## Via YAML

lab_dir=$(PWD)

oc project demo

### jaeger config

oc apply -f ${lab_dir}/deployment/jaegerConfigMap.yaml -n demo

### service A v1

```sh
oc delete AppsodyApplication service-a-v1 -n demo
oc delete --ignore-not-found pipelinerun java-spring-boot2-liberty-service-a-pipeline-run-v1
oc apply -f service-a-pipeline-resources-v1.yaml
oc apply -f service-a-manual-pipeline-run-v1.yaml
```

### service A v2

```sh
oc delete AppsodyApplication service-a-v2 -n demo
oc delete --ignore-not-found pipelinerun java-spring-boot2-liberty-service-a-pipeline-run-v2
oc apply -f service-a-pipeline-resources-v2.yaml
oc apply -f service-a-manual-pipeline-run-v2.yaml
```

### service B v1

```sh
oc delete AppsodyApplication service-b-v1 -n demo
oc delete --ignore-not-found pipelinerun java-spring-boot2-liberty-service-b-manual-pipeline-run-v1
oc apply -f service-b-pipeline-resources-v1.yaml
oc apply -f service-b-manual-pipeline-run-v1.yaml
```

### service B v2

```sh
oc delete AppsodyApplication service-b-v2 -n demo
oc delete --ignore-not-found pipelinerun java-spring-boot2-liberty-service-b-manual-pipeline-run-v2
oc apply -f service-b-pipeline-resources-v2.yaml
oc apply -f service-b-manual-pipeline-run-v2.yaml
```



## Istio

oc project demo

Patch due to issue https://github.com/appsody/appsody-operator/issues/227

```
oc patch service service-a-v1 -n demo -p '{"spec":{"ports":[{"port": 9080, "name":"http"}]}}'
oc patch service service-a-v2 -n demo -p '{"spec":{"ports":[{"port": 9080, "name":"http"}]}}'
oc patch service service-b-v1 -n demo -p '{"spec":{"ports":[{"port": 9080, "name":"http"}]}}'
oc patch service service-b-v2 -n demo -p '{"spec":{"ports":[{"port": 9080, "name":"http"}]}}'

```

```
cd ${lab_dir}
```

Patch due to

```
oc apply -n demo -f lab-jaeger-istio-appsody-sbol/istio/service-a.yaml
```


oc apply -n demo -f lab-jaeger-istio-appsody-sbol/istio/gateway.yaml
oc apply -n demo -f lab-jaeger-istio-appsody-sbol/istio/destination-rules.yaml
oc apply -n demo -f lab-jaeger-istio-appsody-sbol/istio/virtual-service.yaml


### Traffic versioning for A (v1 to v2)

```
oc apply -n demo -f lab-jaeger-istio-appsody-sbol/istio/virtual-service-v1-v2.yaml
```

## Knative

### Add namespace to ServiceMeshMemberRoll
Add the `demo` namespace to the `ServiceMeshMemberRoll` contained in the `knative-serving-ingress` namespace.

https://access.redhat.com/documentation/en-us/openshift_container_platform/4.2/html/serverless_applications/getting-started-knative-services



### service B v3

```sh
oc delete AppsodyApplication service-b-v3 -n demo
oc delete --ignore-not-found pipelinerun java-spring-boot2-liberty-service-b-manual-pipeline-run-v3
oc apply -f service-b-pipeline-resources-v3.yaml
oc apply -f service-b-manual-pipeline-run-v3.yaml
```

Patch due to issue https://github.com/appsody/appsody-operator/issues/227

```
oc patch service service-b-v3 -n demo -p '{"spec":{"ports":[{"port": 9080, "name":"http"}]}}'


## Test

curl service-b-demo.apps.istiodemodn.os.fyre.ibm.com/formatGreeting?name=DNaaa
curl istio-ingressgateway-openshift-operators.apps.cp4adndemo.os.fyre.ibm.com/sayHello/DNaaa
curl istio-ingressgateway-openshift-operators.apps.cp4adndemo.os.fyre.ibm.com/


Issue with
Istio ConfigNamespace: demoIstio Object Type: virtualservicesIstio Object: service-b-v3

  https://kiali.io/documentation/validations/#_kia1102_virtualservice_is_pointing_to_a_non_existent_gateway

  https://istio.io/docs/reference/config/networking/gateway/

  gateways
    - knative-serving/cluster-local-gateway
    - knative-serving/knative-ingress-gateway
