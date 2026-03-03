package com.hoa.maven;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugin.MojoFailureException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.project.MavenProject;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Maven Mojo for validating strict layered architecture compliance.
 *
 * Enforces dependency rules:
 * - Controller → Service, DTO, Config
 * - Service → Repository, Model, DTO, Config, Providers
 * - Repository → Model, Config
 * - Model → (nothing)
 * - DTO → (nothing)
 */
@Mojo(name = "validate", defaultPhase = LifecyclePhase.VERIFY)
public class ArchitectureValidatorMojo extends AbstractMojo {

    @Parameter(defaultValue = "${project}", readonly = true)
    private MavenProject project;

    @Parameter(defaultValue = "${project.basedir}/src/main/java/com/hoa/assistant", readonly = true)
    private File sourceDirectory;

    @Parameter(defaultValue = "false")
    private boolean skip;

    private static final Map<String, Set<String>> ALLOWED_DEPENDENCIES = new HashMap<>();

    static {
        // Define allowed dependency rules per layer
        ALLOWED_DEPENDENCIES.put("controller", Set.of("service", "dto", "config", "exception"));
        ALLOWED_DEPENDENCIES.put("service", Set.of("repository", "model", "dto", "config", "exception", "provider"));
        ALLOWED_DEPENDENCIES.put("repository", Set.of("model", "config", "exception"));
        ALLOWED_DEPENDENCIES.put("model", Set.of("exception"));
        ALLOWED_DEPENDENCIES.put("dto", Set.of("exception"));
    }

    @Override
    public void execute() throws MojoExecutionException, MojoFailureException {
        if (skip) {
            getLog().info("Architecture validation skipped.");
            return;
        }

        if (!sourceDirectory.exists()) {
            getLog().warn("Source directory does not exist: " + sourceDirectory.getAbsolutePath());
            return;
        }

        getLog().info("Validating architecture rules...");

        try {
            List<ArchitectureViolation> violations = validateArchitecture();

            if (!violations.isEmpty()) {
                getLog().error("");
                getLog().error("===== ARCHITECTURE VIOLATIONS DETECTED =====");
                getLog().error("");

                for (ArchitectureViolation violation : violations) {
                    getLog().error(violation.toString());
                }

                getLog().error("");
                getLog().error("See docs/ARCHITECTURE.md for dependency rules");
                getLog().error("");

                throw new MojoFailureException("Architecture validation failed. " + violations.size() + " violation(s) detected.");
            }

            getLog().info("✓ Architecture validation passed!");

        } catch (IOException e) {
            throw new MojoExecutionException("Error reading source files", e);
        }
    }

    private List<ArchitectureViolation> validateArchitecture() throws IOException {
        List<ArchitectureViolation> violations = new ArrayList<>();
        List<Path> javaFiles = findJavaFiles(sourceDirectory.toPath());

        for (Path javaFile : javaFiles) {
            String layer = extractLayer(javaFile);
            if (layer == null) continue;

            String content = Files.readString(javaFile);
            Set<String> imports = extractImports(content);

            for (String importedClass : imports) {
                String importedLayer = extractLayer(importedClass);
                if (importedLayer == null || importedLayer.equals("exception")) continue;

                if (!isAllowedDependency(layer, importedLayer)) {
                    violations.add(new ArchitectureViolation(
                            javaFile.getFileName().toString(),
                            layer,
                            importedLayer,
                            importedClass
                    ));
                }
            }
        }

        return violations;
    }

    private List<Path> findJavaFiles(Path startPath) throws IOException {
        return Files.walk(startPath)
                .filter(path -> path.toString().endsWith(".java"))
                .collect(Collectors.toList());
    }

    private String extractLayer(Path javaFile) {
        String path = javaFile.toString();
        if (path.contains("/controller/")) return "controller";
        if (path.contains("/service/")) return "service";
        if (path.contains("/repository/")) return "repository";
        if (path.contains("/model/")) return "model";
        if (path.contains("/dto/")) return "dto";
        if (path.contains("/config/")) return "config";
        if (path.contains("/exception/")) return "exception";
        return null;
    }

    private String extractLayer(String className) {
        if (className.contains(".controller.")) return "controller";
        if (className.contains(".service.")) return "service";
        if (className.contains(".repository.")) return "repository";
        if (className.contains(".model.")) return "model";
        if (className.contains(".dto.")) return "dto";
        if (className.contains(".config.")) return "config";
        if (className.contains(".exception.")) return "exception";
        return null;
    }

    private Set<String> extractImports(String content) {
        Set<String> imports = new HashSet<>();
        Pattern pattern = Pattern.compile("import\\s+(com\\.hoa\\.assistant[.\\w]+);");
        Matcher matcher = pattern.matcher(content);

        while (matcher.find()) {
            imports.add(matcher.group(1));
        }

        return imports;
    }

    private boolean isAllowedDependency(String fromLayer, String toLayer) {
        Set<String> allowed = ALLOWED_DEPENDENCIES.getOrDefault(fromLayer, new HashSet<>());
        return allowed.contains(toLayer);
    }

    private static class ArchitectureViolation {
        private final String file;
        private final String fromLayer;
        private final String toLayer;
        private final String importedClass;

        ArchitectureViolation(String file, String fromLayer, String toLayer, String importedClass) {
            this.file = file;
            this.fromLayer = fromLayer;
            this.toLayer = toLayer;
            this.importedClass = importedClass;
        }

        @Override
        public String toString() {
            return String.format(
                    "[VIOLATION] %s (%s layer)\n" +
                    "  → Cannot import from %s layer: %s\n" +
                    "  → See docs/ARCHITECTURE.md#dependency-rules",
                    file, fromLayer, toLayer, importedClass
            );
        }
    }
}

