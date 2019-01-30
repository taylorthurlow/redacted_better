require 'spec_helper'

describe Group do
  subject(:group) { create(:group) }

  describe '#artist' do
    context 'when artists count is 1' do
      it 'returns the name of the arist' do
        group.artists = [{ 'name' => 'asdf', 'id' => 123 }]

        expect(group.artist).to eq 'asdf'
      end
    end

    context 'when artists count is 2' do
      it 'returns the names of both artists with an ampersand' do
        group.artists = [{ 'name' => 'asdf', 'id' => 123 }, { 'name' => 'hjkl', 'id' => 456 }]

        expect(group.artist).to eq 'asdf & hjkl'
      end
    end

    context 'when artists count is more than 2' do
      it 'returns various artists' do
        group.artists = [
          { 'name' => 'asdf', 'id' => 123 },
          { 'name' => 'hjkl', 'id' => 456 },
          { 'name' => 'qwer', 'id' => 789 }
        ]

        expect(group.artist).to eq 'Various Artists'
      end
    end
  end

  describe '#artist=' do
    it 'sets the artists variable using string keys' do
      expect {
        group.artist = { 'name' => 'helloworld', 'id' => 1 }
      }.to change(group, :artists).to([{ 'name' => 'helloworld', 'id' => 1 }])
    end

    it 'sets the artists variable using symbol keys' do
      expect {
        group.artist = { name: 'helloworld', id: 1 }
      }.to change(group, :artists).to([{ 'name' => 'helloworld', 'id' => 1 }])
    end
  end

  describe '#formats_missing' do
    it 'gets the missing formats' do
      flac = create(:torrent, group: group, format: 'FLAC', encoding: 'Lossless')
      create(:torrent, group: group, format: 'MP3', encoding: '320', media:
             flac.media, remaster_year: flac.remaster_year, remaster_title:
             flac.remaster_title, remaster_record_label:
             flac.remaster_record_label, remaster_catalogue_number:
             flac.remaster_catalogue_number)

      expect(group.formats_missing(flac)).to eq [['MP3', 'V0 (VBR)']]
    end
  end
end
