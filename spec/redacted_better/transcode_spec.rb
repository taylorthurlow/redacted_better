require "spec_helper"

def generate_flac(bit_depth: 16, sample_rate: 44_100, channels: 2)
  # Generate a sample 24-bit WAV file
  temp_dir = Dir.mktmpdir
  filename = SecureRandom.hex(5)
  audio_file = File.join(temp_dir, filename + ".wav")
  generator = AudioGenerator.new(sample_rate: sample_rate)
  generator.generate_wav(audio_file, bit_depth: bit_depth, channels: channels)

  # Encode the WAV file as a 24-bit FLAC
  output = File.join(temp_dir, "source_24bit.flac")
  `flac --totally-silent --best -o "#{output}" "#{audio_file}"`

  output
end

describe Transcode do
  describe ".transcode" do
    it "transcodes a FLAC" do
      rg = generate_release_group
      group = rg[:group]
      torrent = rg[:torrent]
      allow(FileUtils).to receive(:cp_r)
      allow(described_class).to receive(:transcode_file) do |_, _, _, dest|
        `touch "#{dest}"`
        [0, []]
      end

      expected_dir = File.join(
        $config.fetch(:directories, :output),
        Torrent.build_string(group.artist, group.name, torrent.year,
                             torrent.media,
                             Torrent.build_format("MP3", "V0 (VBR)"))
      )
      expect(described_class.transcode(torrent, "MP3", "V0 (VBR)")).to eq expected_dir
    end

    context "when a torrent fails with a non-zero exit code" do
      it "returns false" do
        rg = generate_release_group
        allow(FileUtils).to receive(:cp_r)
        allow(described_class).to receive(:transcode_file) do |_, _, _, dest|
          `touch "#{dest}"`
          [1, []]
        end

        expect(described_class.transcode(rg[:torrent], "MP3", "V0 (VBR)")).to be false
      end
    end

    context "when a torrent fails with some errors" do
      it "returns false" do
        rg = generate_release_group
        allow(FileUtils).to receive(:cp_r)
        allow(described_class).to receive(:transcode_file) do |_, _, _, dest|
          `touch "#{dest}"`
          [0, ["There was an error somewhere."]]
        end

        expect(described_class.transcode(rg[:torrent], "MP3", "V0 (VBR)")).to be false
      end
    end
  end

  describe ".transcode_file" do
    it "converts from 24-bit to 16-bit FLAC" do
      flac = generate_flac(bit_depth: 24)
      temp_dir = File.dirname(flac)
      output = File.join(temp_dir, "16bit.flac")

      described_class.transcode_file("FLAC", "Lossless", flac, output)

      flacinfo = FlacInfo.new(output)
      expect(flacinfo.streaminfo["bits_per_sample"]).to eq 16

      FileUtils.rm_r temp_dir
    end

    encodings = ["320", "V0 (VBR)", "V2 (VBR)"]

    encodings.each do |encoding|
      it "converts from 16-bit FLAC to MP3 #{encoding}" do
        flac = generate_flac(bit_depth: 16)
        temp_dir = File.dirname(flac)
        output = File.join(temp_dir, "transcode.mp3")

        described_class.transcode_file("MP3", encoding, flac, output)

        FileUtils.rm_r temp_dir
      end

      it "converts from 24-bit FLAC to MP3 #{encoding}" do
        flac = generate_flac(bit_depth: 24)
        temp_dir = File.dirname(flac)
        output = File.join(temp_dir, "transcode.mp3")

        described_class.transcode_file("MP3", encoding, flac, output)

        FileUtils.rm_r temp_dir
      end
    end

    context "when the sample rate is 96000Hz" do
      it "chooses downsamples to 48000Hz" do
        flac = generate_flac(bit_depth: 24, sample_rate: 96_000)
        temp_dir = File.dirname(flac)
        output = File.join(temp_dir, "16bit.flac")

        described_class.transcode_file("FLAC", "Lossless", flac, output)

        flacinfo = FlacInfo.new(output)
        expect(flacinfo.streaminfo["samplerate"]).to eq 48_000

        FileUtils.rm_r temp_dir
      end
    end

    context "when the number of channels is abnormal" do
      it "gives an error" do
        flac = generate_flac(bit_depth: 24, channels: 5)
        temp_dir = File.dirname(flac)
        output = File.join(temp_dir, "16bit.flac")

        _, errors = described_class.transcode_file("FLAC", "Lossless", flac, output)

        expect(errors.first).to eq "Multichannel releases are unsupported - found 5"

        FileUtils.rm_r temp_dir
      end
    end

    context "when the sample rate is abnormal" do
      it "gives an error" do
        flac = generate_flac(bit_depth: 24, sample_rate: 22_050)
        temp_dir = File.dirname(flac)
        output = File.join(temp_dir, "16bit.flac")

        _, errors = described_class.transcode_file("FLAC", "Lossless", flac, output)

        expect(errors.first).to eq "22050Hz sample rate unsupported"

        FileUtils.rm_r temp_dir
      end
    end
  end

  describe ".file_is_24bit?" do
    context "when the file is 24 bit" do
      it "returns true" do
        info = instance_double("FlacInfo", streaminfo: { "bits_per_sample" => 24 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_24bit?("path")).to be true
      end
    end

    context "when the file is not 24 bit" do
      it "returns false" do
        info = instance_double("FlacInfo", streaminfo: { "bits_per_sample" => 16 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_24bit?("path")).to be false
      end
    end
  end

  describe ".file_is_multichannel?" do
    context "when the file is multichannel" do
      it "returns true" do
        info = instance_double("FlacInfo", streaminfo: { "channels" => 3 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_multichannel?("path")).to be true
      end
    end

    context "when the file is not multichannel" do
      it "returns false" do
        info = instance_double("FlacInfo", streaminfo: { "channels" => 2 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_multichannel?("path")).to be false
      end
    end
  end
end
