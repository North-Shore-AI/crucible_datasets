import Config

# Enable fallback to synthetic data in tests to avoid network dependencies
config :crucible_datasets,
  fallback_to_synthetic: true
