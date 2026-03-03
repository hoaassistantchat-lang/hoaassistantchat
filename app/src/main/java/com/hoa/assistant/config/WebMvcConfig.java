package com.hoa.assistant.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    /**
     * Serve static files (the React/HTML chat UI) from the classpath.
     * All non-API routes fall back to index.html so the SPA handles routing.
     */
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/static/**")
                .addResourceLocations("classpath:/static/");

        // Serve index.html at root
        registry.addResourceHandler("/", "/index.html")
                .addResourceLocations("classpath:/static/");

        // Serve admin dashboard
        registry.addResourceHandler("/admin.html")
                .addResourceLocations("classpath:/static/");
    }
}

