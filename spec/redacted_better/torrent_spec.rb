require 'spec_helper'

require 'tempfile'

describe Torrent do
  subject(:torrent) { create(:torrent, group: create(:group)) }

  describe '#properly_contained?' do
    context 'when file path is empty' do
      it 'returns false' do
        torrent.file_path = ''
        expect(torrent.properly_contained?).to be false
      end
    end

    context 'when file path is not empty' do
      it 'returns true' do
        torrent.file_path = '01 -  Bluejuice - Video Games.flac{{{20972757}}}|||'
        expect(torrent.properly_contained?).to be true
      end
    end
  end

  describe '#on_disk?' do
    context 'when flacs_only flag is false' do
      let(:flacs_only) { false }

      context 'when all files are present' do
        it 'returns true' do
          tf1 = Tempfile.new('temp_flac_file.flac')
          tf2 = Tempfile.new('temp_pic_file.jpg')
          torrent.file_list = [tf1.path, tf2.path]

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be true

          tf1.close(true)
          tf2.close(true)
        end
      end

      context 'when not all files are present' do
        it 'returns false' do
          torrent.file_list = ['invalidfilename.flac', 'invalidfilename.jpg']

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be false
        end
      end
    end

    context 'when flacs_only flag is true' do
      let(:flacs_only) { true }

      context 'when all flacs are present' do
        it 'returns true' do
          tf1 = Tempfile.new('temp_flac_file.flac')
          torrent.file_list = [tf1.path, 'invalidfilename.jpg']

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be true

          tf1.close(true)
        end
      end

      context 'when not all files are present' do
        it 'returns false' do
          torrent.file_list = ['invalidfilename.flac', 'invalidfilename.jpg']

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be false
        end
      end
    end
  end

  describe '#flacs' do
    it 'returns files with flac extension' do
      torrent.file_list = %w[abc.flac 123.flac cover.jpg]

      expect(torrent.flacs).to eq %w[abc.flac 123.flac]
    end
  end
end
