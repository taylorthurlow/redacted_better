def generate_artists(count = 1)
  artists = []
  count.times do
    artists << {
      "id" => rand(1..1_000_000),
      "name" => SecureRandom.hex(5),
    }
  end

  artists
end

FactoryBot.define do
  factory :group do
    skip_create

    transient do
      id { rand(1..1_000_000) }
      name { SecureRandom.hex(5) }
      artists { generate_artists }
      year { rand(1950..2020) }
      record_label { SecureRandom.hex(5) }
    end

    initialize_with do
      new(
        "id" => id,
        "name" => name,
        "musicInfo" => { "artists" => artists },
        "year" => year,
        "recordLabel" => record_label,
      )
    end
  end
end
