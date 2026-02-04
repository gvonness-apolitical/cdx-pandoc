-- Pandoc provides these globals at runtime
read_globals = { "pandoc", "PANDOC_SCRIPT_FILE" }
globals = { "Writer", "Template", "Reader" }

-- Test files need to set PANDOC_SCRIPT_FILE before loading modules
files["tests/unit/**"].globals = { "PANDOC_SCRIPT_FILE" }
