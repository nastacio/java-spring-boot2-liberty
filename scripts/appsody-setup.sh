currdir=$PWD
basedir=${currdir}/lab-jaeger-istio-sbol
servicea=${basedir}/service-a
serviceb=${basedir}/service-b

mkdir -p ${servicea}
cd ${servicea}
appsody init experimental/java-spring-boot2-liberty
mkdir -p src/main/java/com/example/servicea
cat<<EOF > src/main/java/com/example/servicea/HelloController.java
package com.example.servicea;

import java.net.URI;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import io.opentracing.Scope;
import io.opentracing.Span;
import io.opentracing.Tracer;

@RestController
public class HelloController {

    static int counter = 1;

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private Tracer tracer;

    @GetMapping("/sayHello/{name}")
    public String sayHello(@PathVariable String name) {
        try (Scope scope = tracer.buildSpan("say-hello-handler").startActive(true)) {
            Span span = scope.span();
            Map<String, String> fields = new LinkedHashMap<>();
            fields.put("event", name);
            fields.put("message", "this is a log message for name " + name);
            span.log(fields);
            // you can also log a string instead of a map, key=event value=<stringvalue>
            // span.log("this is a log message for name " + name);
            span.setBaggageItem("my-baggage", name);
            String response = formatGreetingRemote(name);
            span.setTag("response", response);
            return response;
        }
    }

    private String formatGreeting(String name) {
        try (Scope scope = tracer.buildSpan("format-greeting").startActive(true)) {
            Span span = scope.span();
            span.log("formatting message locally for name " + name);
            String response = "Hello " + name + "!";
            return response;
        }
    }

    private String formatGreetingRemote(String name) {
        String serviceName = System.getenv("SERVICE_FORMATTER");
        if (serviceName == null) {
            serviceName = "localhost";
        }
        String urlPath = "http://" + serviceName + ":9081/formatGreeting";
        URI uri = UriComponentsBuilder //
                .fromHttpUrl(urlPath) //
                .queryParam("name", name).build(Collections.emptyMap());
        ResponseEntity<String> response = restTemplate.getForEntity(uri, String.class);
        return response.getBody();

    }

    @GetMapping("/error")
    public ResponseEntity<String> replyError() {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(null);
    }
}
EOF

cd $currdir
mkdir -p ${serviceb}
cd ${serviceb}
appsody init experimental/java-spring-boot2-liberty

mkdir -p src/main/java/com/example/serviceb
cat<<EOF > src/main/java/com/example/serviceb/FormatController.java
package com.example.serviceb;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.opentracing.Scope;
import io.opentracing.Span;
import io.opentracing.Tracer;

@RestController
public class FormatController {

    @Autowired
    private Tracer tracer;

    @GetMapping("/formatGreeting")
    public String formatGreeting(@RequestParam String name) {
        try (Scope scope = tracer.buildSpan("format-greeting").startActive(true)) {
            Span span = scope.span();
            span.log("formatting message remotely for name " + name);
            String response = "Hello, from service-b " + name + "!";
            String myBaggage = span.getBaggageItem("my-baggage");
            span.log("this is baggage " + myBaggage);
            return response;
        }
    }
}
EOF

# Bring up for local testing

cd ${basedir}
cat > jaeger.properties << EOF
JAEGER_ENDPOINT=http://jaeger-collector:14268/api/traces
JAEGER_REPORTER_LOG_SPANS=true
JAEGER_SAMPLER_TYPE=const
JAEGER_SAMPLER_PARAM=1
JAEGER_PROPAGATION=b3
EOF

docker network create opentrace_network

docker run --name jaeger-collector \
  --detach \
  --rm \
  -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 \
  -p 5775:5775/udp \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 14268:14268 \
  -p 9411:9411 \
  --network opentrace_network \
  jaegertracing/all-in-one:latest

cd ${servicea}
appsody run \
  --name "service-a" \
  --publish 9082:9080 \
  --publish 9446:9443 \
  --docker-options="--env-file ../jaeger.properties --env SERVICE_FORMATTER=service-b" \
  --network opentrace_network

cd ${serviceb}
appsody run \
  --name "service-b" \
  --publish 9081:9080 \
  --publish 9444:9443 \
  --publish 7778:7777 \
  --docker-options="--env-file ../jaeger.properties" \
  --network opentrace_network