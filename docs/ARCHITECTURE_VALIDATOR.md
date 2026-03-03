# Architecture Validator Usage Guide

## Overview

The **Architecture Validator Plugin** automatically enforces strict layered architecture compliance in the HOA Assistant project. It validates that dependencies follow the defined rules during the Maven build lifecycle.

## Running Architecture Validation

### Option 1: Shorthand Command (Recommended)
```powershell
mvn architecture:validate
```

This works because Maven is configured to recognize `com.hoa` as a plugin group in `~/.m2/settings.xml`.

### Option 2: Fully Qualified Plugin Name
```powershell
mvn com.hoa:architecture-validator-plugin:1.0.0-SNAPSHOT:validate
```

### Option 3: As Part of Full Build
```powershell
mvn verify
```

The validator automatically runs during the `verify` phase when building the app module.

### Option 4: Full Build from Root
```powershell
mvn clean verify
```

Builds both the plugin and the application, validating architecture at the end.

## Dependency Rules

The validator enforces these strict dependency rules:

```
✓ Controller can depend on:   Service, DTO, Config, Exception
✓ Service can depend on:      Repository, Model, DTO, Config, Exception, Provider
✓ Repository can depend on:   Model, Config, Exception
✓ Model can depend on:        Exception
✓ DTO can depend on:          Exception
✓ Config can depend on:       (nothing - leaf node)
✓ Exception can depend on:    (nothing - leaf node)

✗ Controller CANNOT depend on:  Repository, Model
✗ Service CANNOT depend on:     Controller
✗ Repository CANNOT depend on:  Service, Controller, DTO
```

## Understanding Violations

If a violation is detected, you'll see output like:

```
===== ARCHITECTURE VIOLATIONS DETECTED =====

[VIOLATION] ChatService.java (service layer)
  → Cannot import from model layer: com.hoa.assistant.repository.TicketRepository
  → See docs/ARCHITECTURE.md#dependency-rules

[VIOLATION] TicketController.java (controller layer)
  → Cannot import from repository layer: com.hoa.assistant.repository.DocumentRepository
  → See docs/ARCHITECTURE.md#dependency-rules

BUILD FAILURE: Architecture validation failed. 2 violation(s) detected.
```

## How It Works

The plugin:
1. Scans all Java source files in `src/main/java`
2. Extracts the layer from the file path (controller/, service/, etc.)
3. Parses all import statements
4. Validates that imports follow the allowed dependency rules
5. Reports any violations with file names and details

## Project Structure for Validation

For the validator to correctly identify layers, organize your code:

```
src/main/java/com/hoa/assistant/
├── controller/          ← HTTP endpoints
│   ├── ChatController.java
│   └── ...
├── service/             ← Business logic
│   ├── ChatService.java
│   └── ...
├── repository/          ← Data access
│   ├── MessageRepository.java
│   └── ...
├── model/               ← Data models
│   ├── Message.java
│   └── ...
├── dto/                 ← Transfer objects
│   ├── ChatRequest.java
│   └── ...
├── config/              ← Configuration
│   └── HoaProperties.java
└── exception/           ← Exceptions
    └── BusinessException.java
```

## Troubleshooting

### "No plugin found for prefix 'architecture'"
- Ensure `~/.m2/settings.xml` exists with the `<pluginGroup>com.hoa</pluginGroup>` entry
- Rebuild the plugin: `mvn -pl architecture-validator-plugin clean install`

### False Positives
If you get violations that seem incorrect:
1. Check the file path contains the layer name (e.g., `/service/` for service layer)
2. Ensure imports are fully qualified (e.g., `com.hoa.assistant.dto.ChatRequest`)
3. Run with debug: `mvn architecture:validate -X` to see detailed scanning

### Skipping Validation
If needed to skip validation temporarily:
```powershell
mvn verify -Darchitecture.skip=true
```

## Modifying Rules

To change the dependency rules, edit:
`architecture-validator-plugin/src/main/java/com/hoa/maven/ArchitectureValidatorMojo.java`

Find the `ALLOWED_DEPENDENCIES` map and update the rules, then rebuild:
```powershell
mvn -pl architecture-validator-plugin clean install
```

## CI/CD Integration

The validator should run in your CI pipeline:

```yaml
# GitHub Actions example
- name: Validate Architecture
  run: mvn clean verify
```

The build will fail if any violations are detected, preventing non-compliant code from being merged.

