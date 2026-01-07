package com.example.hellospring;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
	
	@GetMapping("/hello")
	public String helloWorld() {
		return "Hello, World from Spring Boot!";
	}
	
	//index 루트
	//index 배포 재시도
	@GetMapping("/")
	public String home() {
		return "Welcome to Spring Boot Hello App!";
	}

}
