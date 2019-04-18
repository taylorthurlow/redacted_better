require "spec_helper"

describe Tags do
  let(:valid_tags) {
    { "ARTIST" => "artist",
      "ALBUM" => "album",
      "TITLE" => "title",
      "TRACKNUMBER" => "01" }
  }

  describe ".valid_tags?" do
    it "returns true for valid tags" do
      info = instance_double("FlacInfo", tags: valid_tags)
      allow(FlacInfo).to receive(:new).and_return(info)

      expect(described_class.valid_tags?("path")).to eq(valid: true, errors: [])
    end

    context "when missing" do
      context "the artist tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.reject { |k, _| k == "ARTIST" })
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Missing artist tag."]],
          )
        end
      end

      context "the album tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.reject { |k, _| k == "ALBUM" })
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Missing album tag."]],
          )
        end
      end

      context "the title tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.reject { |k, _| k == "TITLE" })
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Missing title tag."]],
          )
        end
      end

      context "the track number tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.reject { |k, _| k == "TRACKNUMBER" })
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Missing tracknumber tag."]],
          )
        end
      end
    end

    context "when blank" do
      context "artist tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.merge("ARTIST" => ""))
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Blank artist tag."]],
          )
        end
      end

      context "album tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.merge("ALBUM" => ""))
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Blank album tag."]],
          )
        end
      end

      context "title tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.merge("TITLE" => ""))
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Blank title tag."]],
          )
        end
      end

      context "track number tag" do
        it "returns false" do
          info = instance_double("FlacInfo", tags: valid_tags.merge("TRACKNUMBER" => ""))
          allow(FlacInfo).to receive(:new).and_return(info)

          expect(described_class.valid_tags?("path")).to eq(
            valid: false, errors: [["path", "Blank tracknumber tag."]],
          )
        end
      end
    end
  end
end
