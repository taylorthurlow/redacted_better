require "spec_helper"

describe Log do
  describe ".log" do
    context "when global quiet flag is set" do
      before { $quiet = true }

      it "prints nothing" do
        expect { described_class.log("test", false) }.not_to output.to_stdout
      end
    end

    context "when global quiet flag is not set" do
      before { $quiet = false }

      it "prints the log message" do
        expect { described_class.log("test", false) }.to output("test").to_stdout
      end
    end

    context "when newline is true" do
      it "prints the log message with a newline" do
        expect { described_class.log("test", true) }.to output("test\n").to_stdout
      end
    end
  end

  describe "log levels" do
    it "prints in green" do
      expect { described_class.success("test") }.to output(/test/).to_stdout
    end

    it "prints in bright white" do
      expect { described_class.info("test") }.to output(/test/).to_stdout
    end

    it "prints in blue" do
      expect { described_class.debug("test") }.to output(/test/).to_stdout
    end

    it "prints in yellow" do
      expect { described_class.warning("test") }.to output(/test/).to_stdout
    end

    it "prints in red" do
      expect { described_class.error("test") }.to output(/test/).to_stdout
    end
  end
end
