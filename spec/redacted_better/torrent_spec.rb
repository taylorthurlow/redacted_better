require "spec_helper"

require "tempfile"

describe Torrent do
  subject(:torrent) { create(:torrent, group: create(:group)) }

  describe "#properly_contained?" do
    context "when file path is empty" do
      it "returns false" do
        torrent.file_path = ""
        expect(torrent.properly_contained?).to be false
      end
    end

    context "when file path is not empty" do
      it "returns true" do
        torrent.file_path = "01 -  Bluejuice - Video Games.flac{{{20972757}}}|||"
        expect(torrent.properly_contained?).to be true
      end
    end
  end

  describe "#on_disk?" do
    context "when flacs_only flag is false" do
      let(:flacs_only) { false }

      context "when all files are present" do
        it "returns true" do
          tf1 = Tempfile.new("temp_flac_file.flac")
          tf2 = Tempfile.new("temp_pic_file.jpg")
          torrent.file_list = [tf1.path, tf2.path]

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be true

          tf1.close(true)
          tf2.close(true)
        end
      end

      context "when not all files are present" do
        it "returns false" do
          torrent.file_list = ["invalidfilename.flac", "invalidfilename.jpg"]

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be false
        end
      end
    end

    context "when flacs_only flag is true" do
      let(:flacs_only) { true }

      context "when all flacs are present" do
        it "returns true" do
          tf1 = Tempfile.new("temp_flac_file.flac")
          torrent.file_list = [tf1.path, "invalidfilename.jpg"]

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be true

          tf1.close(true)
        end
      end

      context "when not all files are present" do
        it "returns false" do
          torrent.file_list = ["invalidfilename.flac", "invalidfilename.jpg"]

          expect(torrent.on_disk?(flacs_only: flacs_only)).to be false
        end
      end
    end
  end

  describe "#flacs" do
    it "returns files with flac extension" do
      torrent.file_list = %w[abc.flac 123.flac cover.jpg]

      expect(torrent.flacs).to eq %w[abc.flac 123.flac]
    end
  end

  describe "#all_24bit?" do
    before do
      allow(torrent).to receive(:on_disk?).and_return(true)
    end

    context "when all files are 24 bit" do
      it "returns true" do
        allow(Transcode).to receive(:file_is_24bit?).and_return(true)

        expect(torrent.all_24bit?).to be true
      end
    end

    context "when one or more files are not 24 bit" do
      it "returns false" do
        allow(Transcode).to receive(:file_is_24bit?).and_return(false)

        expect(torrent.all_24bit?).to be false
      end
    end
  end

  describe "#mislabeled_24bit?" do
    context "when all files are 24bit" do
      before do
        allow(torrent).to receive(:all_24bit?).and_return(true)
      end

      context "when encoding is 24bit lossless" do
        it "returns false" do
          torrent.encoding = "24bit Lossless"

          expect(torrent.mislabeled_24bit?).to be false
        end
      end

      context "encoding is not 24bit lossless" do
        it "returns true" do
          torrent.encoding = "Lossless"

          expect(torrent.mislabeled_24bit?).to be true
        end
      end
    end

    context "when one or more files are not 24bit" do
      before do
        allow(torrent).to receive(:all_24bit?).and_return(false)
      end

      context "encoding is 24bit lossless" do
        it "returns false" do
          torrent.encoding = "24bit Lossless"

          expect(torrent.mislabeled_24bit?).to be false
        end
      end

      context "encoding is not 24bit lossless" do
        it "returns false" do
          torrent.encoding = "Lossless"

          expect(torrent.mislabeled_24bit?).to be false
        end
      end
    end
  end

  describe "#any_multichannel?" do
    before do
      allow(torrent).to receive(:on_disk?).and_return(true)
    end

    context "when one or more file is multichannel" do
      it "returns true" do
        allow(Transcode).to receive(:file_is_multichannel?).and_return(true)

        expect(torrent.any_multichannel?).to be true
      end
    end

    context "when one or more files are not multichannel" do
      it "returns false" do
        allow(Transcode).to receive(:file_is_multichannel?).and_return(false)

        expect(torrent.any_multichannel?).to be false
      end
    end
  end

  describe "#year" do
    context "when torrent is remastered" do
      before { torrent.remastered = true }

      context "when remaster year is zero" do
        before { torrent.remaster_year = 0 }

        it "returns the group year" do
          torrent.group.year = 1990

          expect(torrent.year).to eq 1990
        end
      end

      context "when remaster year is not zero" do
        before { torrent.remaster_year = 2000 }

        it "returns the remaster year" do
          expect(torrent.year).to eq 2000
        end
      end
    end

    context "when torrent is not remastered" do
      before { torrent.remastered = false }

      it "returns the group year" do
        torrent.group.year = 1990

        expect(torrent.year).to eq 1990
      end
    end
  end

  describe "#to_s" do
    it "builds the string" do
      allow(torrent).to receive(:year).and_return(2000)
      allow(torrent).to receive(:format_shorthand).and_return("FLAC")
      torrent.group.artist = { id: 123, name: "artist" }
      torrent.group.name = "name"
      torrent.media = "CD"

      expect(torrent.to_s).to eq "artist - name (2000) [CD FLAC]"
    end
  end

  describe "#url" do
    it "builds the url" do
      torrent.group.id = 123
      torrent.id = 456

      url = "https://redacted.sh/torrents.php?id=123&torrentid=456"
      expect(torrent.url).to eq url
    end
  end

  describe "#missing_files" do
    it "gets the list of files that do not exist" do
      tf1 = Tempfile.new("temp1.flac")
      tf2 = Tempfile.new("temp2.flac")
      torrent.file_list = [tf1, tf2, "thisfiledoesntexist.flac"]

      expect(torrent.missing_files).to eq ["thisfiledoesntexist.flac"]

      tf1.close(true)
      tf2.close(true)
    end
  end

  describe "#valid_tags?" do
    context "when all files have valid tags" do
      it "returns false" do
        allow(torrent).to receive(:on_disk?).and_return(true)
        allow(Tags).to receive(:valid_tags?).and_return(true)
        expect(torrent.valid_tags?).to be true
      end
    end

    context "when some files have invalid tags" do
      it "returns false" do
        allow(torrent).to receive(:on_disk?).and_return(true)
        allow(Tags).to receive(:valid_tags?).and_return(false)
        expect(torrent.valid_tags?).to be false
      end
    end

    context "when some files are not on disk" do
      it "returns false" do
        allow(torrent).to receive(:on_disk?).and_return(false)
        allow(Tags).to receive(:valid_tags?).and_return(false)
        expect(torrent.valid_tags?).to be false
      end
    end
  end

  describe "#format_shorthand" do
    context "when format is flac" do
      before { torrent.format = "FLAC" }

      it "gets the shorthand for regular flac" do
        torrent.encoding = "Lossless"

        expect(torrent.format_shorthand).to eq "FLAC"
      end

      it "gets the shorthand for 24bit flac" do
        torrent.encoding = "24bit Lossless"

        expect(torrent.format_shorthand).to eq "FLAC24"
      end
    end

    context "when format is MP3" do
      before { torrent.format = "MP3" }

      it "gets the shorthand for 320 MP3" do
        torrent.encoding = "320"

        expect(torrent.format_shorthand).to eq "320"
      end

      it "gets the shorthand for V0 MP3" do
        torrent.encoding = "V0 (VBR)"

        expect(torrent.format_shorthand).to eq "MP3v0"
      end

      it "gets the shorthand for V2 MP3" do
        torrent.encoding = "V2 (VBR)"

        expect(torrent.format_shorthand).to eq "MP3v2"
      end
    end

    context "when format is something else" do
      it "gets the generic shorthand" do
        torrent.format = "asdf"
        torrent.encoding = "hjkl"

        expect(torrent.format_shorthand).to eq "asdf hjkl"
      end
    end
  end

  describe "#make_torrent" do
    it "creates a torrent file" do
      temp_torrent_dir = Dir.mktmpdir
      data_dir = Dir.mktmpdir
      FileUtils.touch(File.join(data_dir, "fake_music_file.flac"))
      allow($config).to receive(:fetch).and_call_original
      allow($config).to receive(:fetch).with(:directories, :torrents).and_return temp_torrent_dir
      $account = instance_double("Account")
      allow($account).to receive(:passkey).and_return "abcd1234"
      allow(torrent).to receive(:`) { `echo this returns 0` }

      result = torrent.make_torrent("FLAC", "Lossless", data_dir)

      expect(result).to be true
    end
  end

  describe ".in_same_release_group?" do
    let(:group) { create(:group) }
    let(:torrent1) { create(:torrent, group: group) }
    let(:torrent2) { create(:torrent, group: group) }
    let(:attributes) {
      [:@media, :@remaster_year, :@remaster_title, :@remaster_record_label,
       :@remaster_catalogue_number]
    }

    before do
      attributes.each do |attr|
        torrent1.instance_variable_set(attr, "asdf")
        torrent2.instance_variable_set(attr, "asdf")
      end
    end

    context "when all attributes are equal" do
      it "returns true" do
        expect(described_class.in_same_release_group?(torrent1, torrent2)).to be true
      end
    end

    it "returns false when media is not equal" do
      torrent2.media = "1234"

      expect(described_class.in_same_release_group?(torrent1, torrent2)).to be false
    end

    it "returns false when remaster year is not equal" do
      torrent2.remaster_year = "1234"

      expect(described_class.in_same_release_group?(torrent1, torrent2)).to be false
    end

    it "returns false when remaster title is not equal" do
      torrent2.remaster_title = "1234"

      expect(described_class.in_same_release_group?(torrent1, torrent2)).to be false
    end

    it "returns false when remaster record label is not equal" do
      torrent2.remaster_record_label = "1234"

      expect(described_class.in_same_release_group?(torrent1, torrent2)).to be false
    end

    it "returns false when remaster catalogue number is not equal" do
      torrent2.remaster_catalogue_number = "1234"

      expect(described_class.in_same_release_group?(torrent1, torrent2)).to be false
    end
  end
end
