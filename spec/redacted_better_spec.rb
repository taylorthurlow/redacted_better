require "spec_helper"

describe RedactedBetter do
  # To customize ARGV options, use `ARGV.replace(args)`. It takes a single
  # array parameter. Example:
  #
  # ARGV.replace ["-q", "--username", "myusername"]
  before do
    ARGV.replace ["--quiet", "--config", "default_config.yaml"]
  end

  describe "#handle_found_release" do
    subject(:redacted_better) { described_class.new }

    let(:group) { create(:group) }
    let(:torrent) { create(:torrent, group: group) }

    before do
      allow(Transcode).to receive(:transcode)
      allow(torrent).to receive(:missing_files).and_return []
      allow(torrent).to receive(:valid_tags?).and_return(
        valid: true, errors: [],
      )
    end

    context "when there are no missing files" do
      it "returns true" do
        expect(redacted_better.send(:handle_found_release, group, torrent)).to be true
      end
    end

    context "when there are missing files" do
      it "returns false" do
        allow(torrent).to receive(:missing_files).and_return ["/some_file.flac"]

        expect(redacted_better.send(:handle_found_release, group, torrent)).to be false
      end
    end

    context "when the torrent is multichannel" do
      it "returns false" do
        allow(torrent).to receive(:any_multichannel?).and_return true

        expect(redacted_better.send(:handle_found_release, group, torrent)).to be false
      end
    end

    context "when the torrent is mislabeled as 16bit" do
      it "marks the torrent as 24bit" do
        allow(torrent).to receive(:mislabeled_24bit?).and_return true

        expect_any_instance_of(RedactedAPI).to receive(:mark_torrent_24bit)
        expect(redacted_better.send(:handle_found_release, group, torrent)).to be true
      end
    end

    context "when there are malformed tags" do
      it "returns false" do
        allow(torrent).to receive(:valid_tags?).and_return(false)

        expect(redacted_better.send(:handle_found_release, group, torrent)).to be false
      end
    end
  end
end
