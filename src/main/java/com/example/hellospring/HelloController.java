package com.example.hellospring;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
	
	@GetMapping("/hello")
	public String helloWorld() {
		return "Hello, World from Spring Boot!";
	}
	
	@GetMapping("/")
	public String home() {
		return "Welcome to Spring Boot Hello App!";
	}

}
