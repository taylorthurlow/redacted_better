require "spec_helper"

# Testing this is a bit odd because this class is typically instantiated via
# the command-line and therefore has many possibilities of options. To make it
# easier to test, we stub out `RedactedBetter#slop_parse` which parses our
# command line options, instead returning some already known set of options.
# $opts is set in `spec_helper.rb` but because RSpec's subject definition is
# lazy loaded, you can set $opts in any spec before referencing the subject,
# and the new $opts will be used.
describe RedactedBetter do
  describe "#handle_found_release" do
    subject(:redacted_better) {
      allow_any_instance_of(described_class).to receive(:slop_parse).and_return($opts)
      described_class.new
    }

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
