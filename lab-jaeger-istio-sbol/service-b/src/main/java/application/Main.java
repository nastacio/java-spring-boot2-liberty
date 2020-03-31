package application;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

import io.jaegertracing.Configuration;

@SpringBootApplication
public class Main {

	@Bean
	public io.opentracing.Tracer initTracer() {
      return Configuration.fromEnv("service-a").getTracer();
	}

	public static void main(String[] args) {
		SpringApplication.run(Main.class, args);
	}

}