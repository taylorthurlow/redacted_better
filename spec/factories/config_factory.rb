FactoryBot.define do
  factory :config do
    skip_create

    transient do
      file_path { "spec/support/test_config.yaml" }
    end

    initialize_with { new(file_path) }
  end
end
