FactoryBot.define do
  factory :torrent do
    skip_create

    transient do
      id { rand(1..1_000_000) }
      media { Torrent.valid_media.sample }
      format { Torrent.valid_format.sample }
      encoding { Torrent.valid_encoding.sample }
      remastered { false }
      remaster_year { remastered ? 0 : rand(1950..2020) }
      remaster_title { remastered ? '' : SecureRandom.hex(5) }
      remaster_record_label { remastered ? '' : SecureRandom.hex(5) }
      remaster_catalogue_number { remastered ? '' : SecureRandom.hex(5) }
      file_path { SecureRandom.hex(5) }
      file_list { generate_file_list }
      user_id { rand(1..1_000_000) }
      username { SecureRandom.hex(5) }
      group { nil }
    end

    initialize_with do
      new({
            'id' => id,
            'media' => media,
            'format' => format,
            'encoding' => encoding,
            'remastered' => remastered,
            'remasterYear' => remaster_year,
            'remasterTitle' => remaster_title,
            'remasterRecordLabel' => remaster_record_label,
            'remasterCatalogueNumber' => remaster_catalogue_number,
            'filePath' => file_path,
            'fileList' => file_list,
            'userId' => user_id,
            'username' => username
          }, group)
    end

    after(:create) do |torrent, evaluator|
      if evaluator.group
        torrent.group.torrents << torrent
      end
    end
  end
end
