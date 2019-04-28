require "spec_helper"

describe SnatchCache do
  describe ".new" do
    context "when invalidate is true" do
      it "deletes the existing cache file" do
        cache_file = Tempfile.new("the_cache")
        allow(File).to receive(:delete)

        described_class.new(cache_file.path, true)

        expect(File).to have_received(:delete).with(cache_file.path)
      end
    end
  end

  describe "#add" do
    it "adds a torrent to the cache" do
      cache_file = Tempfile.new("the_cache").path
      torrent = create(:torrent, group: create(:group))

      described_class.new(cache_file, true).add(torrent)

      contents = JSON.parse(File.read(cache_file))
      expect(contents.count).to eq 1
      expect(contents.first["id"]).to eq torrent.id
    end
  end

  describe "#contains?" do
    context "when the torrent does not exist in the cache" do
      it "returns false" do
        cache_file = Tempfile.new("the_cache").path
        cache = described_class.new(cache_file, true)

        expect(cache.contains?(1)).to be false
      end
    end

    context "when the torrent exists in the cache" do
      it "returns true" do
        cache_file = Tempfile.new("the_cache").path
        torrent = create(:torrent, group: create(:group))
        cache = described_class.new(cache_file, true)
        cache.add(torrent)

        expect(cache.contains?(torrent.id)).to be true
      end
    end
  end
end
