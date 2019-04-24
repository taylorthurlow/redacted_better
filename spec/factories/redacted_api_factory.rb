FactoryBot.define do
  factory :redacted_api, class: RedactedAPI do
    skip_create

    transient do
      user_id { rand(1..1_000_000) }
      cookie { "session=" + SecureRandom.hex(5) }
    end

    initialize_with do
      new(user_id: user_id, cookie: cookie)
    end
  end
end
