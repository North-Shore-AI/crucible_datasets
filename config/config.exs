import Config

# CrucibleDatasets configuration
#
# :fallback_to_synthetic - When true, loaders will fallback to synthetic data
#                          if HuggingFace downloads fail. Default: false
#
# Example:
#   config :crucible_datasets, fallback_to_synthetic: true
#
config :crucible_datasets,
  fallback_to_synthetic: false

# Import environment specific config
import_config "#{config_env()}.exs"
