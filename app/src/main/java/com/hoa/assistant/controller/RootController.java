package com.hoa.assistant.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Serves the SPA (index.html) for root and any unmatched non-API routes.
 */
@Controller
public class RootController {

    @GetMapping(value = {"/"})
    public String root() {
        return "forward:/index.html";
    }
}
