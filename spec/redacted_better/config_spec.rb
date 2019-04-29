require "spec_helper"

describe Config do
  subject(:config) { create(:config) }

  describe ".initialize" do
    context "when the provided path is not found" do
      subject(:config) {
        config_path = File.join(Dir.mktmpdir, "redacted_better.yaml")
        create(:config, file_path: config_path)
      }

      it "creates a new config file and exits" do
        expect {
          config
        }.to raise_error SystemExit
      end
    end

    context "when there is no provided path" do
      it "uses the default config path" do
        allow(described_class).to receive(:config_directory).and_return(Dir.mktmpdir)
        allow_any_instance_of(described_class).to receive(:exit)
        config = create(:config, file_path: nil)
        expect(File.exist?(config.file_path)).to be true
      end
    end
  end

  describe "#fetch" do
    it "gets a configuration option" do
      option = config.fetch(:directories, :download)

      expect(option).to eq "/media/data/torrents/music"
    end
  end
end
