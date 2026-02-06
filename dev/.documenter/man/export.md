
# Export to Config Formats {#Export-to-Config-Formats}

NickelEval can export Nickel code to JSON, TOML, or YAML strings for generating configuration files.

## JSON Export {#JSON-Export}

```julia
nickel_to_json("{ name = \"myapp\", port = 8080 }")
```


Output:

```json
{
  "name": "myapp",
  "port": 8080
}
```


## TOML Export {#TOML-Export}

```julia
nickel_to_toml("{ name = \"myapp\", port = 8080 }")
```


Output:

```toml
name = "myapp"
port = 8080
```


## YAML Export {#YAML-Export}

```julia
nickel_to_yaml("{ name = \"myapp\", port = 8080 }")
```


Output:

```yaml
name: myapp
port: 8080
```


## Generic Export Function {#Generic-Export-Function}

Use `nickel_export` with the `format` keyword:

```julia
nickel_export("{ a = 1 }"; format=:json)
nickel_export("{ a = 1 }"; format=:toml)
nickel_export("{ a = 1 }"; format=:yaml)
```


## Generating Config Files {#Generating-Config-Files}

### Example: Generate Multiple Formats {#Example:-Generate-Multiple-Formats}

```julia
config = """
{
  database = {
    host = "localhost",
    port = 5432,
    name = "mydb"
  },
  server = {
    host = "0.0.0.0",
    port = 8080
  },
  logging = {
    level = "info",
    file = "/var/log/app.log"
  }
}
"""

# Generate TOML config
write("config.toml", nickel_to_toml(config))

# Generate YAML config
write("config.yaml", nickel_to_yaml(config))

# Generate JSON config
write("config.json", nickel_to_json(config))
```


### Example: Environment-Specific Configs {#Example:-Environment-Specific-Configs}

```julia
base_config = """
{
  app_name = "myapp",
  log_level = "info"
}
"""

dev_overrides = """
{
  debug = true,
  database = { host = "localhost" }
}
"""

prod_overrides = """
{
  debug = false,
  database = { host = "db.production.com" }
}
"""

# Merge and export
dev_config = nickel_export("$base_config & $dev_overrides"; format=:toml)
prod_config = nickel_export("$base_config & $prod_overrides"; format=:toml)
```


## Nested Structures {#Nested-Structures}

TOML handles nested records as sections:

```julia
nickel_to_toml("""
{
  server = {
    host = "0.0.0.0",
    port = 8080
  }
}
""")
```


Output:

```toml
[server]
host = "0.0.0.0"
port = 8080
```

