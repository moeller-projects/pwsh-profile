## 1. Startup correctness

- [x] 1.1 Import the local module directly before deferred initialization.
- [x] 1.2 Make module-path handling portable and remove wrapper-module exports.
- [x] 1.3 Document host-specific profile setup.

## 2. Startup performance and safety

- [x] 2.1 Make prompt, completion, and git integrations opt in or deferred.
- [x] 2.2 Remove module enumeration and unnecessary default imports.
- [x] 2.3 Remove remote download-and-execute profile commands.
- [x] 2.4 Keep dotenv activation and Starship initialization out of completion setup.

## 3. Verification

- [ ] 3.1 Repair and run the startup benchmark and smoke test.
- [x] 3.2 Validate the OpenSpec change.
