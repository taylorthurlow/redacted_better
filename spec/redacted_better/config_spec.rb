require "spec_helper"

describe Config do
  describe ".load_config" do
    before do
      @old_config = $opts[:config]
      path = File.join("tmp", SecureRandom.hex(5) + ".yaml")
      FileUtils.cp("spec/support/test_config.yaml", path)
      $opts[:config] = path
    end

    after do
      $opts[:config] = @old_config
    end

    context "when there is a config path provided" do
      context "and the file exists" do
        it "returns the config" do
          expect(described_class.load_config).to be_a TTY::Config
        end
      end

      context "and the file does not exist" do
        it "exits" do
          $opts[:config] = "doesnotexist.yaml"

          expect { described_class.load_config }.to raise_error SystemExit
        end
      end
    end

    context "when there is no config path provided" do
      it "uses the default location and creates the file" do
        allow(described_class).to receive(:default_config_path)
                                    .and_return(File.dirname($opts[:config]))
        $opts[:config] = nil

        expect { described_class.load_config }.to raise_error SystemExit
      end
    end
  end
end
